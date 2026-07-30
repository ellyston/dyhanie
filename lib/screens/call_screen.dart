import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  final String? otherUser;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.roomCode,
    required this.username,
    required this.otherUser,
    required this.isIncoming,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallWebRTCService? _rtc;
  final _db = FirebaseDatabase.instance.ref();
  final _remoteRenderer = RTCVideoRenderer();

  String statusText = 'Подключение...';
  bool muted = false;
  bool speakerOn = false;
  bool connected = false;
  bool _closing = false;

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
    _watchCallStatus();
    _startRtc();

    // если не ответили / не соединились — 45 сек
    _ringTimeout = Timer(const Duration(seconds: 45), () async {
      if (!connected && mounted && !_closing) {
        await _db.child('rooms').child(widget.roomCode).child('call').update({
          'status': 'no_answer',
        });
        await _finish();
      }
    });
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
  }

  void _attachRemote(MediaStream stream) {
    _remoteRenderer.srcObject = stream;
    if (!mounted) return;
    setState(() {
      connected = true;
      statusText = 'Идёт звонок';
    });
    _startTimer();
    HapticFeedback.lightImpact();
  }

  void _watchCallStatus() {
    _callStatusSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('call')
        .onValue
        .listen((event) {
      if (_closing) return;
      if (event.snapshot.value == null) {
        _finish();
        return;
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final st = data['status']?.toString() ?? '';
      if (st == 'rejected' || st == 'ended' || st == 'no_answer') {
        _finish();
      }
      if (st == 'accepted' && mounted && !connected) {
        setState(() => statusText = 'Соединение...');
      }
    });
  }

  Future<void> _startRtc() async {
    final other = widget.otherUser;
    if (other == null || other.isEmpty) {
      setState(() => statusText = 'Нет собеседника');
      return;
    }

    final isCaller = !widget.isIncoming;

    if (widget.isIncoming) {
      await _db
          .child('rooms')
          .child(widget.roomCode)
          .child('call')
          .update({'status': 'accepted'});
    }

    _rtc = CallWebRTCService(
      roomCode: widget.roomCode,
      username: widget.username,
      otherUser: other,
      isCaller: isCaller,
    );

    _remoteSub = _rtc!.remoteStream.listen(_attachRemote);

    _rtcStatusSub = _rtc!.status.listen((s) {
      if (!mounted || _closing) return;
      setState(() {
        if (!connected) {
          if (s == 'mic_ok') {
            statusText = isCaller ? 'Вызов...' : 'Соединение...';
          } else if (s == 'offer_sent') {
            statusText = 'Вызов...';
          } else if (s == 'answer_sent' || s == 'answer_set') {
            statusText = 'Соединение...';
          } else if (s == 'link_lost') {
            statusText = 'Связь потеряна';
          } else if (s.startsWith('Ошибка') || s.startsWith('error')) {
            statusText = s;
          }
        }
        if (s == 'remote_audio' || s == 'connected') {
          connected = true;
          statusText = 'Идёт звонок';
          _startTimer();
        }
      });
    });

    try {
      await _rtc!.start();
    } catch (e) {
      if (mounted) setState(() => statusText = 'Ошибка: $e');
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

  Future<void> _hangUp() async {
    if (_closing) return;
    await _db.child('rooms').child(widget.roomCode).child('call').update({
      'status': 'ended',
    });
    await _finish();
  }

  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    _ringTimeout?.cancel();
    await _rtc?.hangUp();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.otherUser ?? '…';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: RTCVideoView(_remoteRenderer),
            ),
            Column(
              children: [
                const SizedBox(height: 48),
                Icon(
                  connected ? Icons.phone_in_talk : Icons.ring_volume,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 20),
                Text(
                  '@$other',
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  connected ? _timeLabel : statusText,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _roundBtn(
                      icon: muted ? Icons.mic_off : Icons.mic,
                      color: muted ? Colors.orangeAccent : Colors.white24,
                      label: muted ? 'Микрофон' : 'Микрофон',
                      onTap: _toggleMute,
                    ),
                    _roundBtn(
                      icon: Icons.call_end,
                      color: Colors.redAccent,
                      onTap: _hangUp,
                      big: true,
                    ),
                    _roundBtn(
                      icon: speakerOn ? Icons.volume_up : Icons.hearing,
                      color: speakerOn ? Colors.blueAccent : Colors.white24,
                      label: speakerOn ? 'Динамик' : 'Ухо',
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
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
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ],
    );
  }
}