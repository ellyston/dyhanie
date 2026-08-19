import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_incoming_call_payload.dart';

/// Мост Dart ↔ native (Android FCM / iOS CallKit).
/// Пока native не подключён — безопасный no-op.
class SystemIncomingCallChannel {
  SystemIncomingCallChannel._();
  static final instance = SystemIncomingCallChannel._();

  static const _method = MethodChannel('su.dyhanie/system_incoming_call');
  static const _events = EventChannel('su.dyhanie/system_incoming_call_events');

  StreamSubscription? _sub;
  final _incomingCtrl =
      StreamController<SystemIncomingCallPayload>.broadcast();

  /// Нативные события: accepted / declined / incoming_from_push
  Stream<SystemIncomingCallPayload> get onAccepted =>
      _incomingCtrl.stream;

  bool _attached = false;

  Future<void> attach() async {
    if (_attached) return;
    _attached = true;

    try {
      _sub = _events.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is! Map) return;
          final type = event['type']?.toString() ?? '';
          final data = event['payload'];
          if (data is! Map) return;
          final payload = SystemIncomingCallPayload.fromMap(data);
          if (!payload.isValid) return;

          if (type == 'accepted' || type == 'incoming') {
            _incomingCtrl.add(payload);
          }
          // declined — пока игнорируем на Dart-стороне
        },
        onError: (e) {
          debugPrint('SystemIncomingCallChannel events error: $e');
        },
      );
    } catch (e) {
      debugPrint('SystemIncomingCallChannel attach: $e');
    }
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }

  /// Зарегистрировать push-token на вашем signal (когда native отдаст token).
  Future<String?> getPushToken() async {
    try {
      final t = await _method.invokeMethod<String>('getPushToken');
      return t;
    } catch (_) {
      return null; // stub / нет native
    }
  }

  /// Показать системный входящий (если app сам инициирует — редко).
  Future<void> showIncoming(SystemIncomingCallPayload payload) async {
    try {
      await _method.invokeMethod('showIncoming', payload.toMap());
    } catch (e) {
      debugPrint('showIncoming stub/no-native: $e');
    }
  }

  Future<void> endSystemCall() async {
    try {
      await _method.invokeMethod('endCall');
    } catch (_) {}
  }
}