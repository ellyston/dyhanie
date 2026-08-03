import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/dyhanie_key/dyhanie_key_stub.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import 'pin_setup_screen.dart';

class RestorePhraseScreen extends StatefulWidget {
  final VoidCallback? onRestored;

  const RestorePhraseScreen({
    super.key,
    this.onRestored,
  });

  @override
  State<RestorePhraseScreen> createState() => _RestorePhraseScreenState();
}

class _RestorePhraseScreenState extends State<RestorePhraseScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resetLocalAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('avatar');
    await prefs.remove('pin_code');
    await prefs.remove('pin_hash');
    await prefs.remove('pin_enabled');
    await prefs.remove('pin');
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      if (k.startsWith('chat_history_') ||
          k.startsWith('chat_cfg_') ||
          k == 'chats_pinned' ||
          k == 'chats_notes') {
        await prefs.remove(k);
      }
    }
    await prefs.setBool('recovery_phrase_shown', true);
    await prefs.setBool('identity_restored_stub', true);
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    final words = raw
        .split(RegExp(r'[\s,;]+'))
        .map((w) => w.trim().toLowerCase())
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.length != 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('restore_phrase_need_24'))),
      );
      return;
    }

    setState(() => _busy = true);
    final ok = await dyhanieKey.restoreFromPhrase(words);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('restore_phrase_fail'))),
      );
      return;
    }

    await _resetLocalAccount();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('restore_phrase_ok'))),
    );
    widget.onRestored?.call();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      (_) => false,
    );
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
          L.t('restore_phrase_title'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L.t('restore_phrase_hint'),
                style: FontService.style(
                  color: onSurf.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.t('recovery_phrase_stub_note'),
                style: FontService.style(
                  color: onSurf.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: FontService.style(color: onSurf),
                  decoration: InputDecoration(
                    hintText: L.t('restore_phrase_placeholder'),
                    hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: onSurf.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(L.t('restore_phrase_action')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}