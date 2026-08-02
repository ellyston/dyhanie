import 'package:shared_preferences/shared_preferences.dart';

import 'locale_service.dart';

/// Режимы автоблокировки приложения.
enum AutoLockMode {
  /// Блокировать каждый раз при уходе в фон / сворачивании.
  onMinimize,

  /// Блокировать, если не заходили дольше [timeoutMinutes].
  afterTimeout,
}

class AutoLockService {
  static final AutoLockService _i = AutoLockService._();
  factory AutoLockService() => _i;
  AutoLockService._();

  static const _keyMode = 'auto_lock_mode';
  static const _keyMinutes = 'auto_lock_minutes';
  static const _keyLastActive = 'auto_lock_last_active';
  static const _keyEnabled = 'auto_lock_enabled';

  static const minMinutes = 1;
  static const maxMinutes = 120;

  AutoLockMode mode = AutoLockMode.afterTimeout;
  int timeoutMinutes = 5; // 0 = никогда
  bool enabled = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    enabled = p.getBool(_keyEnabled) ?? true;
    final m = p.getString(_keyMode);
    mode = m == AutoLockMode.onMinimize.name
        ? AutoLockMode.onMinimize
        : AutoLockMode.afterTimeout;
    timeoutMinutes = p.getInt(_keyMinutes) ?? 5;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyEnabled, enabled);
    await p.setString(_keyMode, mode.name);
    await p.setInt(_keyMinutes, timeoutMinutes);
  }

  Future<void> markActive() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
  }

  Future<int?> lastActiveMs() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyLastActive);
  }

  Future<bool> shouldLock({required bool comingFromBackground}) async {
    if (!enabled) return false;

    if (mode == AutoLockMode.onMinimize) {
      return comingFromBackground;
    }

    if (timeoutMinutes <= 0) return false;

    final last = await lastActiveMs();
    if (last == null) return true;

    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= timeoutMinutes * 60 * 1000;
  }

  /// Подпись для UI (локализованная).
  String get summary {
    if (!enabled) return L.t('disabled');
    if (mode == AutoLockMode.onMinimize) return L.t('lock_on_minimize');
    if (timeoutMinutes <= 0) return L.t('never');
    if (timeoutMinutes == 1) return L.t('after_1_min');
    if (timeoutMinutes < 60) {
      return L.tParams('after_n_min', {'n': '$timeoutMinutes'});
    }
    final h = timeoutMinutes ~/ 60;
    final m = timeoutMinutes % 60;
    if (m == 0) return L.tParams('after_n_h', {'n': '$h'});
    return L.tParams('after_h_m', {'h': '$h', 'm': '$m'});
  }
}