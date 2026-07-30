import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/locale_service.dart';

/// Базовый набор + кастомные из SharedPreferences (ключ emoji_custom)
class EmojiPickerScreen extends StatefulWidget {
  const EmojiPickerScreen({super.key});

  @override
  State<EmojiPickerScreen> createState() => _EmojiPickerScreenState();
}

class _EmojiPickerScreenState extends State<EmojiPickerScreen> {
  static const _prefKey = 'emoji_custom';

  static const _builtin = <String>[
    '😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊',
    '😇', '🙂', '😉', '😍', '🥰', '😘', '😗', '😋',
    '😜', '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏',
    '😣', '😥', '😮', '🤐', '😯', '😪', '😫', '🥱',
    '😴', '😌', '😛', '😝', '🤤', '😒', '😓', '😔',
    '😕', '🙃', '🤑', '😲', '☹️', '🙁', '😖', '😞',
    '😟', '😤', '😢', '😭', '😦', '😧', '😨', '😩',
    '🤯', '😬', '😰', '😱', '🥵', '🥶', '😳', '🤪',
    '😵', '😡', '😠', '🤬', '😷', '🤒', '🤕', '🤢',
    '👍', '👎', '👏', '🙌', '🤝', '✌️', '🤞', '🤟',
    '🤘', '👌', '🤌', '👆', '👇', '👉', '👈', '👋',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘',
    '🔥', '✨', '⭐', '🌟', '💫', '🎉', '🎊', '💯',
    '✅', '❌', '⚡', '💨', '🌊', '🌬️', '🍃', '🌱',
  ];

  List<String> _custom = [];

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefKey) ?? [];
    if (!mounted) return;
    setState(() => _custom = list);
  }

  Future<void> _addCustom() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(L.t('add_emoji'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 28),
          decoration: InputDecoration(
            hintText: '🙂',
            hintStyle: const TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L.t('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(L.t('save'), style: const TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    // берём первый «кластер» (emoji)
    final emoji = value.characters.first;
    if (_custom.contains(emoji) || _builtin.contains(emoji)) return;
    final next = [..._custom, emoji];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, next);
    if (!mounted) return;
    setState(() => _custom = next);
  }

  void _pick(String emoji) => Navigator.pop(context, emoji);

  @override
  Widget build(BuildContext context) {
    final all = [..._custom, ..._builtin];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(L.t('emoji'), style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: L.t('add_emoji'),
            icon: const Icon(Icons.add, color: Colors.white70),
            onPressed: _addCustom,
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: all.length,
        itemBuilder: (context, i) {
          final e = all[i];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pick(e),
            child: Center(
              child: Text(e, style: const TextStyle(fontSize: 26)),
            ),
          );
        },
      ),
    );
  }
}