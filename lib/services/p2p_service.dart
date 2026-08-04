import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_ice.dart';

class P2PService {
  final String roomCode;
  final String username;
  final String otherUser;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;

  final _messageController = StreamController<String>.broadcast();
  Stream<String> get messages => _messageController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get status => _statusController.stream;

  StreamSubscription? _sdpSub;
  StreamSubscription? _candSub;

  bool _isOfferer = false;
  bool _closed = false;
  bool _remoteSet = false;
  bool _opened = false;

  final List<RTCIceCandidate> _pendingCandidates = [];

  P2PService({
    required this.roomCode,
    required this.username,
    required this.otherUser,
  });

  DatabaseReference get _myRef =>
      _db.child('rooms').child(roomCode).child('webrtc').child(username);

  DatabaseReference get _otherRef =>
      _db.child('rooms').child(roomCode).child('webrtc').child(otherUser);

  Future<void> connect() async {
    _isOfferer = username.compareTo(otherUser) < 0;
    _statusController.add('connecting');

    try {
      await _myRef.remove();
    } catch (_) {}

    _pc = await createPeerConnection(WebRtcIce.config);


    // Negotiated DataChannel — создаём с обеих сторон с одним id
    _channel = await _pc!.createDataChannel(
      'chat',
      RTCDataChannelInit()
        ..ordered = true
        ..negotiated = true
        ..id = 1,
    );
    _setupChannel(_channel!);

    _pc!.onIceCandidate = (candidate) {
      if (_closed) return;
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;

      _myRef.child('candidates').push().set({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      _statusController.add('pc:$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markOpen();
      }
    };

    _pc!.onIceConnectionState = (state) {
      _statusController.add('ice:$state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _markOpen();
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _statusController.add('ice_failed');
      }
    };

    if (_isOfferer) {
      await Future.delayed(const Duration(milliseconds: 800));
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _myRef.child('sdp').set({
        'type': offer.type,
        'sdp': offer.sdp,
      });
      _statusController.add('offer_sent');
    } else {
      _statusController.add('waiting_offer');
    }

    _listenOtherSdp();
    _listenOtherCandidates();
  }

  void _markOpen() {
    if (_opened || _closed) return;
    _opened = true;
    _statusController.add('p2p_open');
  }

  void _setupChannel(RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.text != null && message.text!.isNotEmpty) {
        _messageController.add(message.text!);
      }
    };

    channel.onDataChannelState = (state) {
      _statusController.add('dc:$state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _markOpen();
      }
    };
  }

  void _listenOtherSdp() {
    _sdpSub = _otherRef.child('sdp').onValue.listen((event) async {
      if (_closed || _pc == null) return;
      if (event.snapshot.value == null) return;
      if (_remoteSet) return;

      try {
        final sdpMap = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final type = sdpMap['type']?.toString();
        final sdp = sdpMap['sdp']?.toString();
        if (type == null || sdp == null) return;

        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
        _remoteSet = true;
        _statusController.add('remote_set');

        for (final c in _pendingCandidates) {
          try {
            await _pc!.addCandidate(c);
          } catch (_) {}
        }
        _pendingCandidates.clear();
        _statusController.add('pending_flushed');

        if (!_isOfferer && type == 'offer') {
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          await _myRef.child('sdp').set({
            'type': answer.type,
            'sdp': answer.sdp,
          });
          _statusController.add('answer_sent');
        }
      } catch (e) {
        _statusController.add('sdp_error: $e');
      }
    });
  }

  void _listenOtherCandidates() {
    _candSub = _otherRef.child('candidates').onChildAdded.listen((event) async {
      if (_closed || _pc == null) return;
      if (event.snapshot.value == null) return;

      try {
        final c = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

        final candStr = c['candidate']?.toString();
        final sdpMid = c['sdpMid']?.toString();

        int? sdpMLineIndex;
        final raw = c['sdpMLineIndex'];
        if (raw is int) {
          sdpMLineIndex = raw;
        } else if (raw is double) {
          sdpMLineIndex = raw.toInt();
        } else if (raw != null) {
          sdpMLineIndex = int.tryParse(raw.toString());
        }

        if (candStr == null || candStr.isEmpty) return;

        final candidate = RTCIceCandidate(candStr, sdpMid, sdpMLineIndex);

        if (!_remoteSet) {
          _pendingCandidates.add(candidate);
          _statusController.add('cand_queued');
          return;
        }

        await _pc!.addCandidate(candidate);
        _statusController.add('cand_added');
      } catch (e) {
        _statusController.add('cand_error: $e');
      }
    });
  }

  void send(String text) {
    if (_channel != null &&
        _channel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _channel!.send(RTCDataChannelMessage(text));
    }
  }

  bool get isOpen =>
      _opened &&
      _channel != null &&
      _channel!.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> dispose() async {
    _closed = true;

    await _sdpSub?.cancel();
    await _candSub?.cancel();

    try {
      await _channel?.close();
    } catch (_) {}

    try {
      await _pc?.close();
    } catch (_) {}

    try {
      await _myRef.remove();
    } catch (_) {}

    await _messageController.close();
    await _statusController.close();
  }
}