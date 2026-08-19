import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppIconBadge {
  AppIconBadge._();
  static final instance = AppIconBadge._();

  static const _ch = MethodChannel('su.dyhanie/app_badge');
  int _last = -1;

  Future<void> setCount(int count) async {
    final n = count < 0 ? 0 : count;
    if (n == _last) return;
    _last = n;
    try {
      await _ch.invokeMethod('setBadge', {'count': n});
    } catch (e) {
      debugPrint('AppIconBadge: $n ($e)');
    }
  }

  Future<void> clear() => setCount(0);
}