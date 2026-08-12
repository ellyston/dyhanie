import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/call_screen.dart';
import 'dyhanie_api.dart';
import 'contact_invite_service.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Входящие call_offer, пока приложение на переднем плане.
/// Не заменяет FCM/CallKit (фон / убитое приложение).
class IncomingCallService {
  IncomingCallService._();
  static final IncomingCallService instance = IncomingCallService._();

  StreamSubscription? _sub;
  GlobalKey<NavigatorState>? _navKey;
  String? _myUsername;
  bool _busy = false;

  /// Room, который уже слушает открытый ChatScreen (не дублировать).
  String? chatHandlingRoom;

  void attach({
    required GlobalKey<NavigatorState> navKey,
    required String myUsername,
  }) {
    _navKey = navKey;
    _myUsername = myUsername.toLowerCase().trim();
    _sub?.cancel();
    _sub = DyhanieApi.instance.events.listen(_onEvent);
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    _navKey = null;
    _myUsername = null;
    chatHandlingRoom = null;
    _busy = false;
  }

  void setChatHandlingRoom(String? room) {
    chatHandlingRoom = room;
  }

  Future<void> _onEvent(Map<String, dynamic> m) async {
    if (m['type']?.toString() != 'signal') return;
    final p = m['payload'];
    if (p is! Map) return;

    final kind = p['kind']?.toString() ?? '';
    if (kind != 'call_offer') return;

    final me = _myUsername;
    if (me == null || me.isEmpty) return;

    final from = p['from']?.toString() ?? '';
    if (from.isEmpty || from == me) return;

     // Чёрный список — звонок не открываем
    if (await ContactInviteService().isBlocked(from)) return;

    final room = p['room']?.toString() ?? '';
    if (room.isEmpty) return;

    // этот чат уже открыт — handler в ChatScreen
    if (chatHandlingRoom != null && chatHandlingRoom == room) return;
    if (_busy) return;

    final data = p['data'];
    Map? offer;
    if (data is Map) {
      offer = Map<String, dynamic>.from(data);
    }

    _openIncoming(room: room, from: from, offer: offer);
  }

  Future<void> _openIncoming({
    required String room,
    required String from,
    Map? offer,
  }) async {
    final nav = _navKey?.currentState;
    if (nav == null) return;

    _busy = true;
    try {
      HapticFeedback.mediumImpact();
      await nav.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            roomCode: room,
            username: _myUsername!,
            otherUser: from,
            isIncoming: true,
            initialOffer: offer,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
  }
}