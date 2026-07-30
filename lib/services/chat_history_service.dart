import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryService {
  String _key(String roomCode) => 'chat_history_$roomCode';

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
}