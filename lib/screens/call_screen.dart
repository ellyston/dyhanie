import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/call_webrtc_service.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/dyhanie_api.dart';

StreamSubscription? _peerSignalSub;

class CallScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  final String? otherUser;
  final bool isIncoming;
  /// SDP offer, если экран открыли уже по call_offer (иначе callee его не увидит).
  final Map? initialOffer;

  const CallScreen({
    super.key,
    required this.roomCode,
    required this.username,
    required this.otherUser,
    required this.isIncoming,
    this.initialOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallWebRTCService? _rtc;
  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();
  StreamSubscription? _localSub;
  bool cameraOn = true;

  late String statusText;
  bool muted = false;
  bool speakerOn = false;
  bool connected = false;
  bool _closing = false; 
  bool _accepted = false; // входящий ещё не принял

  Timer? _timer;
  Timer? _ringTimeout;
  int seconds = 0;

  StreamSubscription? _callStatusSub;
  StreamSubscription? _rtcStatusSub;
  StreamSubscription? _remoteSub;

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _listenPeerSignals();

    if (widget.isIncoming) {
      _accepted = false;
      statusText = L.t('incoming_call');
    } else {
      _accepted = true;
      statusText = L.t('call_connecting');
      _startRtc();
    }

    _ringTimeout = Timer(const Duration(seconds: 45), () async {
      if (!connected && mounted && !_closing) {
        await _finish();
      }
    }); 
  }

  Future<void> _accept() async {
    if (_accepted || _closing) return;
    setState(() {
      _accepted = true;
      statusText = L.t('call_connecting');
    });
    await _startRtc();
  }

  Future<void> _decline() async {
    await _notifyPeer('call_decline');
    await _finish(notifyPeer: false);
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  void _attachRemote(MediaStream stream) {
    _remoteRenderer.srcObject = stream;
    if (!mounted) return;
    setState(() {
      connected = true;
      statusText = L.t('call_in_progress');
    });
    _startTimer();
    HapticFeedback.lightImpact();
  }

  void _listenPeerSignals() {
    _peerSignalSub?.cancel();
    final other = widget.otherUser;
    if (other == null || other.isEmpty) return;

    _peerSignalSub = DyhanieApi.instance.events.listen((m) {
      if (_closing) return;
      if (m['type']?.toString() != 'signal') return;
      final p = m['payload'];
      if (p is! Map) return;
      if (p['room']?.toString() != widget.roomCode) return;
      if (p['from']?.toString() != other) return;

      final kind = p['kind']?.toString() ?? '';
      if (kind == 'call_decline' || kind == 'call_hangup') {
        if (mounted) {
          setState(() => statusText = L.t('decline_call'));
        }
        _finish(notifyPeer: false);
      }
    });
  }

  Future<void> _notifyPeer(String kind) async {
    final other = widget.otherUser;
    if (other == null || other.isEmpty) return;
    try {
      await DyhanieApi.instance.signal(
        room: widget.roomCode,
        to: other,
        kind: kind,
        data: {'from': widget.username},
      );
    } catch (_) {}
  }

  Future<void> _finish({bool notifyPeer = false}) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    _ringTimeout?.cancel();
    if (notifyPeer) {
      await _notifyPeer('call_hangup');
    }
    await _rtc?.hangUp();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _hangUp() async {
    if (_closing) return;
    await _finish(notifyPeer: true);
  }


  Future<void> _startRtc() async {
    final other = widget.otherUser;
    if (other == null || other.isEmpty) {
      setState(() => statusText = L.t('call_no_peer'));
      return;
    }

    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() => statusText = 'Нужны камера и микрофон');
      }
      return;
    }

    

    final isCaller = !widget.isIncoming;


    _rtc = CallWebRTCService(
      roomCode: widget.roomCode,
      username: widget.username,
      otherUser: other,
      isCaller: isCaller,
      initialOffer: widget.initialOffer,
    );
    
    _remoteSub = _rtc!.remoteStream.listen(_attachRemote);
    _localSub?.cancel();
    _localSub = _rtc!.localStream.listen((stream) {
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    });

    _rtcStatusSub = _rtc!.status.listen((s) {
      if (!mounted || _closing) return;
      setState(() {
        if (!connected) {
          if (s == 'mic_ok') {
            statusText =
                isCaller ? L.t('call_calling') : L.t('call_connecting');
          } else if (s == 'offer_sent') {
            statusText = L.t('call_calling');
          } else if (s == 'answer_sent' || s == 'answer_set') {
            statusText = L.t('call_connecting');
          } else if (s == 'link_lost') {
            statusText = L.t('call_link_lost');
          } else if (s.startsWith('Ошибка') || s.startsWith('error')) {
            statusText = s;
          }
        }
        if (s == 'remote_audio' || s == 'connected') {
          connected = true;
          statusText = L.t('call_in_progress');
          _startTimer();
        }
      });
    });

    try {
      await _rtc!.start();
    } catch (e) {
      if (mounted) setState(() => statusText = '${L.t('error')}: $e');
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    _ringTimeout?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  String get _timeLabel {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleMute() async {
    setState(() => muted = !muted);
    await _rtc?.setMuted(muted);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => speakerOn = !speakerOn);
    await _rtc?.setSpeaker(speakerOn);
  }

  Future<void> _toggleCamera() async {
    setState(() => cameraOn = !cameraOn);
    await _rtc?.setCameraEnabled(cameraOn);
  }

  Future<void> _switchCamera() async {
    await _rtc?.switchCamera();
  }


  @override
  void dispose() {
    _timer?.cancel();
    _ringTimeout?.cancel();
    _callStatusSub?.cancel();
    _rtcStatusSub?.cancel();
    _remoteSub?.cancel();
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    _rtc?.dispose();
    _peerSignalSub?.cancel();
    _localSub?.cancel();
    _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.otherUser ?? '…';
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Удалённое видео
            if (connected)
              RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Container(
                color: bg,
                alignment: Alignment.center,
                child: Icon(
                  Icons.videocam,
                  size: 64,
                  color: onSurf.withValues(alpha: 0.25),
                ),
              ),

            // Локальное превью
            Positioned(
              right: 16,
              top: 16,
              width: 110,
              height: 160,
              child: GestureDetector(
                onTap: _switchCamera,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: Colors.black54,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),

            // Имя и статус
            Positioned(
              left: 16,
              right: 16,
              top: 20,
              child: Column(
                children: [
                  Text(
                    '@$other',
                    style: FontService.style(
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    connected ? _timeLabel : statusText,
                    style: FontService.style(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Кнопки
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: widget.isIncoming && !_accepted
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _roundBtn(
                          icon: Icons.call_end,
                          color: Colors.redAccent,
                          label: L.t('decline_call'),
                          onTap: _decline,
                          big: true,
                        ),
                        _roundBtn(
                          icon: Icons.call,
                          color: Colors.green,
                          label: L.t('accept_call'),
                          onTap: _accept,
                          big: true,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _roundBtn(
                          icon: muted ? Icons.mic_off : Icons.mic,
                          color: muted
                              ? Colors.orangeAccent
                              : Colors.white24,
                          label: L.t('mic'),
                          onTap: _toggleMute,
                        ),
                        _roundBtn(
                          icon: cameraOn
                              ? Icons.videocam
                              : Icons.videocam_off,
                          color: cameraOn
                              ? Colors.white24
                              : Colors.orangeAccent,
                          label: 'Камера',
                          onTap: _toggleCamera,
                        ),
                        _roundBtn(
                          icon: Icons.call_end,
                          color: Colors.redAccent,
                          onTap: _hangUp,
                          big: true,
                        ),
                        _roundBtn(
                          icon: speakerOn
                              ? Icons.volume_up
                              : Icons.hearing,
                          color: speakerOn
                              ? Colors.blueAccent
                              : Colors.white24,
                          label: speakerOn
                              ? L.t('speaker')
                              : L.t('earpiece'),
                          onTap: _toggleSpeaker,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool big = false,
    String? label,
  }) {
    final size = big ? 72.0 : 56.0;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: big ? 32 : 24),
          ),
        ),
        if (label != null && !big) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: FontService.style(
              fontSize: 11,
              color: onSurf.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }
}