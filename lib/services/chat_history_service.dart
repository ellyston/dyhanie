import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryService {
  static const prefix = 'chat_history_';

  String _key(String roomCode) => '$prefix$roomCode';

  Future<void> save(String roomCode, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final list = messages.map((m) {
      return {
        'key': m['key'],
        'text': m['text'],
        'username': m['username'],
        'timestamp': m['timestamp'],
        'ttl': m['ttl'],
        'p2p': m['p2p'],
        'replyText': m['replyText'],
        'replyUser': m['replyUser'],
        'image': m['image'],
        'status': m['status'],
      };
    }).toList();
    await prefs.setString(_key(roomCode), jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> load(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(roomCode));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clear(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(roomCode));
  }

  /// Список всех сохранённых чатов для экрана «Чаты».
  Future<List<Map<String, dynamic>>> listSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <Map<String, dynamic>>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final roomCode = key.substring(prefix.length);
      if (roomCode.isEmpty) continue;

      final msgs = await load(roomCode);
      if (msgs.isEmpty) continue;

      int lastTs = 0;
      String preview = '';
      for (final m in msgs) {
        final ts = m['timestamp'] is int
            ? m['timestamp'] as int
            : int.tryParse('${m['timestamp']}') ?? 0;
        if (ts >= lastTs) {
          lastTs = ts;
          final text = m['text']?.toString() ?? '';
          final hasImg = m['image'] != null;
          preview = text.isNotEmpty ? text : (hasImg ? '🖼' : '');
        }
      }

      result.add({
        'roomCode': roomCode,
        'updatedAt': lastTs,
        'preview': preview,
        'count': msgs.length,
      });
    }

    result.sort(
      (a, b) => (b['updatedAt'] as int).compareTo(a['updatedAt'] as int),
    );
    return result;
  }
}