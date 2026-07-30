import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';

import 'p2p_service.dart';

/// Очистка диалога: локальные сообщения, Firebase, сигнал P2P clear_chat.
class ChatWipeService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Полная очистка «везде».
  ///
  /// [cancelTimers] — отмена TTL-таймеров
  /// [clearLocal] — что сделать с локальным списком (обычно setState(() => messages = []))
  /// [p2p] / [p2pConnected] — отправка clear_chat собеседнику
  Future<void> wipeEverywhere({
    required String roomCode,
    required Map<String, Timer> timers,
    required Map<String, int> remaining,
    required void Function() clearLocal,
    P2PService? p2p,
    required bool p2pConnected,
  }) async {
    // 1) таймеры
    for (final t in timers.values) {
      t.cancel();
    }
    timers.clear();
    remaining.clear();

    // 2) локальный UI
    clearLocal();

    // 3) P2P
    if (p2pConnected && p2p != null) {
      try {
        p2p.send(jsonEncode({'type': 'clear_chat'}));
      } catch (_) {}
    }

    // 4) сервер
    final room = _db.child('rooms').child(roomCode);
    await room.child('messages').remove();
    await room.child('deletes').remove();
    await room.child('meta').child('pinned').remove();
    await room.child('call').remove();
    await room.child('webrtc').remove();
  }

  /// Убрать presence/typing текущего пользователя.
  Future<void> leavePresence({
    required String roomCode,
    required String username,
  }) async {
    final room = _db.child('rooms').child(roomCode);
    await room.child('presence').child(username).remove();
    await room.child('typing').child(username).remove();
  }

  /// true, если в presence никого нет.
  Future<bool> isRoomEmpty(String roomCode) async {
    final snap =
        await _db.child('rooms').child(roomCode).child('presence').get();
    return snap.value == null ||
        (snap.value is Map && (snap.value as Map).isEmpty);
  }

  /// Удалить комнату целиком.
  Future<void> removeRoom(String roomCode) async {
    await _db.child('rooms').child(roomCode).remove();
  }
}