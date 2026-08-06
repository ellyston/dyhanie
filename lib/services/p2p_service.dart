import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'dyhanie_api.dart';
import 'webrtc_ice.dart';

class P2PService {
  final String roomCode;
  final String username;
  final String otherUser;

  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;

  final _messageController = StreamController<String>.broadcast();
  Stream<String> get messages => _messageController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get status => _statusController.stream;

  StreamSubscription? _signalSub;

  bool _isOfferer = false;
  bool _closed = false;
  bool _remoteSet = false;
  bool _opened = false;
  bool _offerHandled = false;

  final List<RTCIceCandidate> _pendingCandidates = [];

  P2PService({
    required this.roomCode,
    required this.username,
    required this.otherUser,
  });

  Future<void> connect() async {
    _isOfferer = username.compareTo(otherUser) < 0;
    _statusController.add('connecting');

    await WebRtcIce.load();
    _pc = await createPeerConnection(WebRtcIce.config);

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
      _sendSignal('candidate', {
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

    _signalSub = DyhanieApi.instance.events.listen(_onSignalEvent);

    if (_isOfferer) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (_closed || _pc == null) return;
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _sendSignal('offer', {
        'type': offer.type,
        'sdp': offer.sdp,
      });
      _statusController.add('offer_sent');
    } else {
      _statusController.add('waiting_offer');
    }
  }

  Future<void> _sendSignal(String kind, dynamic data) async {
    try {
      await DyhanieApi.instance.signal(
        room: roomCode,
        to: otherUser,
        kind: kind,
        data: data,
      );
    } catch (e) {
      _statusController.add('signal_err:$e');
    }
  }

  void _onSignalEvent(Map<String, dynamic> msg) {
    if (_closed || _pc == null) return;
    if (msg['type']?.toString() != 'signal') return;

    final p = msg['payload'];
    if (p is! Map) return;

    final room = p['room']?.toString();
    final from = p['from']?.toString();
    final kind = p['kind']?.toString();
    if (room != roomCode || from != otherUser) return;

    final data = p['data'];
    if (kind == 'offer' || kind == 'answer') {
      _handleSdp(kind!, data);
    } else if (kind == 'candidate') {
      _handleCandidate(data);
    }
  }

  Future<void> _handleSdp(String kind, dynamic data) async {
    if (_pc == null || data is! Map) return;
    if (kind == 'offer' && _offerHandled) return;

    try {
      final type = data['type']?.toString() ?? kind;
      final sdp = data['sdp']?.toString();
      if (sdp == null || sdp.isEmpty) return;

      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteSet = true;
      if (kind == 'offer') _offerHandled = true;
      _statusController.add('remote_set');

      for (final c in _pendingCandidates) {
        try {
          await _pc!.addCandidate(c);
        } catch (_) {}
      }
      _pendingCandidates.clear();

      if (!_isOfferer && kind == 'offer') {
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        await _sendSignal('answer', {
          'type': answer.type,
          'sdp': answer.sdp,
        });
        _statusController.add('answer_sent');
      }
    } catch (e) {
      _statusController.add('sdp_error: $e');
    }
  }

  Future<void> _handleCandidate(dynamic data) async {
    if (_pc == null || data is! Map) return;
    try {
      final candStr = data['candidate']?.toString();
      final sdpMid = data['sdpMid']?.toString();
      int? sdpMLineIndex;
      final raw = data['sdpMLineIndex'];
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
        return;
      }
      await _pc!.addCandidate(candidate);
      _statusController.add('cand_added');
    } catch (e) {
      _statusController.add('cand_error: $e');
    }
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
    await _signalSub?.cancel();
    _signalSub = null;
    try {
      await _channel?.close();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    await _messageController.close();
    await _statusController.close();
  }
}