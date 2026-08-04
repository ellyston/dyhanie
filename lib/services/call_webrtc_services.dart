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

  final _remoteStreamCtrl = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamCtrl.stream;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get status => _statusCtrl.stream;

  StreamSubscription? _offerSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _candidateSub;

  DatabaseReference get _callRef =>
      _db.child('rooms').child(roomCode).child('webrtc');

 

  Future<void> start() async {
    _statusCtrl.add('init');
    _pc = await createPeerConnection(WebRtcIce.config);

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null) return;
      _callRef.child('candidates').child(username).push().set({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (state) {
      _statusCtrl.add('pc:$state');
    };

    _pc!.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        _remoteStreamCtrl.add(e.streams.first);
        _statusCtrl.add('remote_audio');
      }
    };

    // локальный микрофон
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    _statusCtrl.add('mic_ok');

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
    await _callRef.child('offer').set({
      'sdp': offer.sdp,
      'type': offer.type,
      'from': username,
    });
    _statusCtrl.add('offer_sent');
    _listenAnswer();
  }

  Future<void> _listenOffer() async {
    _offerSub = _callRef.child('offer').onValue.listen((event) async {
      if (event.snapshot.value == null) return;
      if (_pc == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (data['from'] == username) return;
      if (_pc!.remoteDescription != null) return;

      final sdp = RTCSessionDescription(
        data['sdp']?.toString(),
        data['type']?.toString(),
      );
      await _pc!.setRemoteDescription(sdp);
      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await _pc!.setLocalDescription(answer);
      await _callRef.child('answer').set({
        'sdp': answer.sdp,
        'type': answer.type,
        'from': username,
      });
      _statusCtrl.add('answer_sent');
    });
  }

  void _listenAnswer() {
    _answerSub = _callRef.child('answer').onValue.listen((event) async {
      if (event.snapshot.value == null || _pc == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (data['from'] == username) return;
      if (_pc!.remoteDescription != null) return;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          data['sdp']?.toString(),
          data['type']?.toString(),
        ),
      );
      _statusCtrl.add('answer_set');
    });
  }

  void _listenCandidates() {
    // чужие кандидаты
    _candidateSub =
        _callRef.child('candidates').child(otherUser).onChildAdded.listen((event) async {
      if (event.snapshot.value == null || _pc == null) return;
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

  Future<void> hangUp() async {
    await _offerSub?.cancel();
    await _answerSub?.cancel();
    await _candidateSub?.cancel();

    await _localStream?.dispose();
    _localStream = null;

    await _pc?.close();
    _pc = null;

    try {
      await _callRef.remove();
    } catch (_) {}

    _statusCtrl.add('ended');
  }

  void dispose() {
    hangUp();
    _remoteStreamCtrl.close();
    _statusCtrl.close();
  }
}