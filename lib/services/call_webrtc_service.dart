import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_ice.dart';

class CallWebRTCService {
  final String roomCode;
  final String username;
  final String otherUser;
  final bool isCaller;

  CallWebRTCService({
    required this.roomCode,
    required this.username,
    required this.otherUser,
    required this.isCaller,
  });

  final _db = FirebaseDatabase.instance.ref();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  bool _remoteSet = false;
  bool _answerSet = false;
  bool _disposed = false;

  final _remoteStreamCtrl = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamCtrl.stream;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get status => _statusCtrl.stream;

  StreamSubscription? _offerSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _candidateSub;

  DatabaseReference get _webrtcRef =>
      _db.child('rooms').child(roomCode).child('webrtc');



  Future<void> start() async {
    if (_disposed) return;
    _statusCtrl.add('init');

    // чистим старый signaling, чтобы повторный звонок не брал прошлый offer
    if (isCaller) {
      try {
        await _webrtcRef.remove();
      } catch (_) {}
    }

    await WebRtcIce.load();
    _pc = await createPeerConnection(WebRtcIce.config);

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || _disposed) return;
      _webrtcRef.child('candidates').child(username).push().set({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      if (_disposed) return;
      _statusCtrl.add('pc:$state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _statusCtrl.add('connected');
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _statusCtrl.add('link_lost');
      }
    };

    _pc!.onTrack = (RTCTrackEvent e) {
      if (_disposed) return;
      if (e.streams.isNotEmpty) {
        _remoteStreamCtrl.add(e.streams.first);
        _statusCtrl.add('remote_audio');
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    _statusCtrl.add('mic_ok');

    // по умолчанию разговорный режим (не динамик)
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _listenCandidates();

    if (isCaller) {
      await _createOffer();
    } else {
      await _listenOffer();
    }
  }

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });
    await _pc!.setLocalDescription(offer);
    await _webrtcRef.child('offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
      'from': username,
    });
    _statusCtrl.add('offer_sent');
    _listenAnswer();
  }

  Future<void> _listenOffer() async {
    _offerSub = _webrtcRef.child('offer').onValue.listen((event) async {
      if (_disposed || event.snapshot.value == null || _pc == null) return;
      if (_remoteSet) return;

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (data['from'] == username) return;

      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          data['sdp']?.toString(),
          data['type']?.toString(),
        ),
      );
      _remoteSet = true;

      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _pc!.setLocalDescription(answer);
      await _webrtcRef.child('answer').set({
        'sdp': answer.sdp,
        'type': answer.type,
        'from': username,
      });
      _statusCtrl.add('answer_sent');
    });
  }

  void _listenAnswer() {
    _answerSub = _webrtcRef.child('answer').onValue.listen((event) async {
      if (_disposed || event.snapshot.value == null || _pc == null) return;
      if (_answerSet) return;

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (data['from'] == username) return;

      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          data['sdp']?.toString(),
          data['type']?.toString(),
        ),
      );
      _answerSet = true;
      _statusCtrl.add('answer_set');
    });
  }

  void _listenCandidates() {
    _candidateSub = _webrtcRef
        .child('candidates')
        .child(otherUser)
        .onChildAdded
        .listen((event) async {
      if (_disposed || event.snapshot.value == null || _pc == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      try {
        await _pc!.addCandidate(
          RTCIceCandidate(
            data['candidate']?.toString(),
            data['sdpMid']?.toString(),
            data['sdpMLineIndex'] is int
                ? data['sdpMLineIndex'] as int
                : int.tryParse('${data['sdpMLineIndex']}'),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> setMuted(bool muted) async {
    final tracks = _localStream?.getAudioTracks() ?? [];
    for (final t in tracks) {
      t.enabled = !muted;
    }
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }

  Future<void> hangUp() async {
    if (_disposed) return;
    _disposed = true;

    await _offerSub?.cancel();
    await _answerSub?.cancel();
    await _candidateSub?.cancel();

    final tracks = _localStream?.getTracks() ?? [];
    for (final t in tracks) {
      await t.stop();
    }
    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    try {
      await _webrtcRef.remove();
    } catch (_) {}

    if (!_statusCtrl.isClosed) _statusCtrl.add('ended');
  }

  void dispose() {
    hangUp();
    _remoteStreamCtrl.close();
    _statusCtrl.close();
  }
}