import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';
import 'chat_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String username;
  const JoinRoomScreen({super.key, required this.username});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('join_by_code'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              style: FontService.style(
                fontSize: 28,
                letterSpacing: 10,
                color: onSurf,
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: L.t('room_code'),
                hintStyle: TextStyle(
                  color: onSurf.withValues(alpha: 0.3),
                  letterSpacing: 10,
                ),
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: onSurf.withValues(alpha: 0.25)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: onSurf),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: onSurf,
                  foregroundColor: bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final code = _controller.text.trim().toUpperCase();
                  if (code.length == 6) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          roomCode: code,
                          username: widget.username,
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  L.t('join'),
                  style: FontService.style(fontSize: 18, color: bg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}