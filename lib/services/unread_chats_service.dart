import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dyhanie_api.dart';

/// Непрочитанные server-msg по dialogId (room).
class UnreadChatsService {
  UnreadChatsService._();
  static final UnreadChatsService instance = UnreadChatsService._();

  static const _prefsKey = 'unread_chats_v1';

  final _ctrl = StreamController<Map<String, int>>.broadcast();
  StreamSubscription? _eventSub;
  Map<String, int> _map = {};

  Stream<Map<String, int>> get changes => _ctrl.stream;
  Map<String, int> get snapshot => Map.unmodifiable(_map);

  /// Сколько диалогов с непрочитанными (для бейджа на home).
  int get dialogCount => _map.values.where((n) => n > 0).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        j.forEach((k, v) {
          final n = v is int ? v : int.tryParse('$v') ?? 0;
          if (n > 0) _map[k] = n;
        });
      } catch (_) {}
    }
    _ctrl.add(snapshot);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_map));
    _ctrl.add(snapshot);
  }

  /// Слушать msg.incoming на уровне приложения (вызывать после bind).
  void startListening({String? openRoomCode}) {
    _eventSub?.cancel();
    _eventSub = DyhanieApi.instance.events.listen((m) async {
      if (m['type']?.toString() != 'msg.incoming') return;
      final p = m['payload'];
      if (p is! Map) return;
      final room = p['room']?.toString() ?? '';
      if (room.isEmpty) return;
      // уже в этом чате — не копить (чат сам ack'нет)
      if (openRoomCode != null && openRoomCode == room) return;
      await add(room, 1);
    });

    _eventSub = DyhanieApi.instance.events.listen((m) async {
      final t = m['type']?.toString();
      if (t == 'msg.incoming') {
        final p = m['payload'];
        if (p is! Map) return;
        final room = p['room']?.toString() ?? '';
        if (room.isEmpty) return;
        if (openRoomCode != null && openRoomCode == room) return;
        await add(room, 1);
      } else if (t == 'chat.nudge_incoming') {
        final p = m['payload'];
        if (p is! Map) return;
        final room = p['room']?.toString() ?? '';
        if (room.isEmpty) return;
        if (openRoomCode != null && openRoomCode == room) return;
        await add(room, 1); // бейдж как у сообщения
      }
    });

  }


  void stopListening() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  Future<void> add(String dialogId, int delta) async {
    if (dialogId.isEmpty || delta == 0) return;
    final n = (_map[dialogId] ?? 0) + delta;
    if (n <= 0) {
      _map.remove(dialogId);
    } else {
      _map[dialogId] = n;
    }
    await _persist();
  }

  Future<void> clear(String dialogId) async {
    if (_map.remove(dialogId) != null) await _persist();
  }

  int countFor(String dialogId) => _map[dialogId] ?? 0;
}