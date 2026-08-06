import 'dart:async';
import 'dart:convert';

import 'p2p_service.dart';

class ChatWipeService {
  Future<void> wipeEverywhere({
    required String roomCode,
    required Map<String, Timer> timers,
    required Map<String, int> remaining,
    required void Function() clearLocal,
    P2PService? p2p,
    required bool p2pConnected,
  }) async {
    for (final t in timers.values) {
      t.cancel();
    }
    timers.clear();
    remaining.clear();
    clearLocal();
    if (p2pConnected && p2p != null) {
      try {
        p2p.send(jsonEncode({'type': 'clear_chat'}));
      } catch (_) {}
    }
  }

  Future<void> leavePresence({
    required String roomCode,
    required String username,
  }) async {}

  Future<bool> isRoomEmpty(String roomCode) async => true;

  Future<void> removeRoom(String roomCode) async {}
}