import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  static const supportEmail = 'support@dyhanie.app';

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('ask_empty'))),
      );
      return;
    }

    setState(() => _sending = true);

    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': L.t('ask_subject'),
        'body': text,
      },
    );

    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('ask_mail_fail'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('ask_mail_fail'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

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
          L.t('ask_question'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L.t('ask_hint'),
              style: FontService.style(
                fontSize: 14,
                color: onSurf.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 8,
              style: FontService.style(color: onSurf),
              decoration: InputDecoration(
                hintText: L.t('ask_placeholder'),
                hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                filled: true,
                fillColor: onSurf.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: onSurf,
                  foregroundColor: bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _sending ? null : _send,
                child: _sending
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: bg,
                        ),
                      )
                    : Text(
                        L.t('send'),
                        style: FontService.style(fontSize: 16, color: bg),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}