import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CallScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  final String? otherUser;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.roomCode,
    required this.username,
    this.otherUser,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool muted = false;
  bool speakerOn = true;
  bool cameraOn = false;
  Duration duration = Duration.zero;
  Timer? _timer;
  StreamSubscription? _callSub;
  String statusText = 'Соединение...';

  @override
  void initState() {
    super.initState();
    statusText = widget.isIncoming ? 'Звонок' : 'Вызов...';

    _callSub = _db.child('rooms').child(widget.roomCode).child('call').onValue.listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final status = data['status']?.toString();

      if (status == 'accepted' && _timer == null) {
        setState(() => statusText = 'Разговор');
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => duration += const Duration(seconds: 1));
        });
      }

      if (status == 'rejected' || status == 'ended' || status == 'no_answer') {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  String get _timeText {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    _db.child('rooms').child(widget.roomCode).child('call').update({
      'status': 'ended',
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final letter = (widget.otherUser ?? widget.username).isNotEmpty
        ? (widget.otherUser ?? widget.username)[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              widget.otherUser != null ? '@${widget.otherUser}' : 'Ожидание...',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 8),
            Text(
              statusText == 'Разговор' ? _timeText : statusText,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Видео-заглушка
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white12,
                        child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 36)),
                      ),
                      const SizedBox(height: 16),
                      Icon(
                        cameraOn ? Icons.videocam : Icons.videocam_off,
                        color: Colors.white24,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cameraOn ? 'Камера (заглушка)' : 'Видео выкл',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(muted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 32),
                  onPressed: () => setState(() => muted = !muted),
                ),
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.redAccent, size: 42),
                  onPressed: _endCall,
                ),
                IconButton(
                  icon: Icon(speakerOn ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 32),
                  onPressed: () => setState(() => speakerOn = !speakerOn),
                ),
                IconButton(
                  icon: Icon(cameraOn ? Icons.videocam : Icons.videocam_off, color: Colors.white, size: 32),
                  onPressed: () => setState(() => cameraOn = !cameraOn),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}