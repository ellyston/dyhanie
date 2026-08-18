import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'dyhanie_api.dart';
import 'webrtc_ice.dart';

class CallWebRTCService {
  final String roomCode;
  final String username;
  final String otherUser;
  final bool isCaller;
  final Map? initialOffer;

  CallWebRTCService({
    required this.roomCode,
    required this.username,
    required this.otherUser,
    required this.isCaller,
    this.initialOffer,
  });

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  bool _remoteSet = false;
  bool _answerSet = false;
  bool _disposed = false;

  final _remoteStreamCtrl = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamCtrl.stream;

  final _localStreamCtrl = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get localStream => _localStreamCtrl.stream;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get status => _statusCtrl.stream;

  StreamSubscription? _signalSub;

  Future<void> start() async {
    if (_disposed) return;
    _statusCtrl.add('init');

    await WebRtcIce.load();
    _pc = await createPeerConnection(WebRtcIce.config);

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || _disposed) return;
      _sendSignal('call_candidate', {
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
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      },
    });
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    if (!_localStreamCtrl.isClosed) {
      _localStreamCtrl.add(_localStream!);
    }
    _statusCtrl.add('mic_ok');

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _signalSub = DyhanieApi.instance.events.listen(_onSignal);

    if (isCaller) {
      await _createOffer();
    } else {
      _statusCtrl.add('waiting_offer');
      if (initialOffer != null) {
        await _onOffer(initialOffer);
      }
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
      _statusCtrl.add('signal_err:$e');
    }
  }

  void _onSignal(Map<String, dynamic> msg) {
    if (_disposed || _pc == null) return;
    if (msg['type']?.toString() != 'signal') return;
    final p = msg['payload'];
    if (p is! Map) return;
    if (p['room']?.toString() != roomCode) return;
    if (p['from']?.toString() != otherUser) return;

    final kind = p['kind']?.toString();
    final data = p['data'];
    if (kind == 'call_offer') {
      _onOffer(data);
    } else if (kind == 'call_answer') {
      _onAnswer(data);
    } else if (kind == 'call_candidate') {
      _onCandidate(data);
    }
  }

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _pc!.setLocalDescription(offer);
    await _sendSignal('call_offer', {
      'sdp': offer.sdp,
      'type': offer.type,
      'from': username,
    });
    _statusCtrl.add('offer_sent');
  }

  Future<void> _onOffer(dynamic data) async {
    if (_remoteSet || data is! Map) return;
    await _pc!.setRemoteDescription(
      RTCSessionDescription(
        data['sdp']?.toString(),
        data['type']?.toString(),
      ),
    );
    _remoteSet = true;

    final answer = await _pc!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _pc!.setLocalDescription(answer);
    await _sendSignal('call_answer', {
      'sdp': answer.sdp,
      'type': answer.type,
      'from': username,
    });
    _statusCtrl.add('answer_sent');
    await _flushCandidates();
  }

  Future<void> _onAnswer(dynamic data) async {
    if (_answerSet || data is! Map) return;
    await _pc!.setRemoteDescription(
      RTCSessionDescription(
        data['sdp']?.toString(),
        data['type']?.toString(),
      ),
    );
    _answerSet = true;
    _remoteSet = true;
    _statusCtrl.add('answer_set');
    await _flushCandidates();
  }

  Future<void> _onCandidate(dynamic data) async {
    if (data is! Map || _pc == null) return;
    final c = RTCIceCandidate(
      data['candidate']?.toString(),
      data['sdpMid']?.toString(),
      data['sdpMLineIndex'] is int
          ? data['sdpMLineIndex'] as int
          : int.tryParse('${data['sdpMLineIndex']}'),
    );
    if (!_remoteSet) {
      _pendingCandidates.add(c);
      return;
    }
    try {
      await _pc!.addCandidate(c);
    } catch (_) {}
  }

  Future<void> _flushCandidates() async {
    for (final c in _pendingCandidates) {
      try {
        await _pc!.addCandidate(c);
      } catch (_) {}
    }
    _pendingCandidates.clear();
  }

  Future<void> setMuted(bool muted) async {
    for (final t in _localStream?.getAudioTracks() ?? []) {
      t.enabled = !muted;
    }
  }

  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }

    Future<void> setCameraEnabled(bool enabled) async {
    for (final t in _localStream?.getVideoTracks() ?? []) {
      t.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (_) {}
  }

  Future<void> hangUp() async {
    if (_disposed) return;
    _disposed = true;
    await _signalSub?.cancel();
    _signalSub = null;

    for (final t in _localStream?.getTracks() ?? []) {
      await t.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    await _pc?.close();
    _pc = null;

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    if (!_statusCtrl.isClosed) _statusCtrl.add('ended');
  }

  void dispose() {
    hangUp();
    if (!_localStreamCtrl.isClosed) _localStreamCtrl.close();
    if (!_remoteStreamCtrl.isClosed) _remoteStreamCtrl.close();
    if (!_statusCtrl.isClosed) _statusCtrl.close();
  }

 final List<RTCIceCandidate> _pendingCandidates = [];

}