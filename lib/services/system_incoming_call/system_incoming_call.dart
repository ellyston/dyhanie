import 'dart:async';

import 'package:flutter/material.dart';

import '../../screens/call_screen.dart';
import 'system_incoming_call_channel.dart';
import 'system_incoming_call_payload.dart';

export 'system_incoming_call_payload.dart';

/// Общая точка: foreground = IncomingCallService (WS),
/// killed/background = native push → channel → этот фасад → CallScreen.
class SystemIncomingCall {
  SystemIncomingCall._();
  static final instance = SystemIncomingCall._();

  GlobalKey<NavigatorState>? _navKey;
  String? _myUsername;
  StreamSubscription? _sub;
  bool _busy = false;

  /// Вызвать после логина (рядом с IncomingCallService.attach).
  void attach({
    required GlobalKey<NavigatorState> navKey,
    required String myUsername,
  }) {
    _navKey = navKey;
    _myUsername = myUsername.toLowerCase().trim();
    unawaited(SystemIncomingCallChannel.instance.attach());
    _sub?.cancel();
    _sub = SystemIncomingCallChannel.instance.onAccepted.listen(_onAccepted);
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    _navKey = null;
    _myUsername = null;
    _busy = false;
    unawaited(SystemIncomingCallChannel.instance.detach());
  }

  Future<void> _onAccepted(SystemIncomingCallPayload p) async {
    if (!p.isValid || _busy) return;
    final me = _myUsername;
    final nav = _navKey?.currentState;
    if (me == null || nav == null) return;
    if (p.from == me) return;

    _busy = true;
    try {
      await nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen(
            roomCode: p.room,
            username: me,
            otherUser: p.from,
            isIncoming: true,
            initialOffer: p.offer,
          ),
        ),
      );
    } finally {
      _busy = false;
      unawaited(SystemIncomingCallChannel.instance.endSystemCall());
    }
  }

  /// Токен для отправки на signal.dyhanie.su (когда появится API).
  Future<String?> pushToken() =>
      SystemIncomingCallChannel.instance.getPushToken();
}