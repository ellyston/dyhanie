import 'package:shared_preferences/shared_preferences.dart';

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

  /// 0 = никогда (только если mode == afterTimeout и minutes == 0)
  static const minMinutes = 1;
  static const maxMinutes = 120; // ползунок до 2ч; «никогда» = отдельная точка

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

  /// Нужно ли показать PIN-экран.
  Future<bool> shouldLock({required bool comingFromBackground}) async {
    if (!enabled) return false;

    if (mode == AutoLockMode.onMinimize) {
      // при каждом возврате из фона
      return comingFromBackground;
    }

    // afterTimeout
    if (timeoutMinutes <= 0) return false; // никогда

    final last = await lastActiveMs();
    if (last == null) return true;

    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= timeoutMinutes * 60 * 1000;
  }

  /// Подпись для UI.
  String get summary {
    if (!enabled) return 'Выключена';
    if (mode == AutoLockMode.onMinimize) return 'При сворачивании';
    if (timeoutMinutes <= 0) return 'Никогда';
    if (timeoutMinutes == 1) return 'Через 1 мин';
    if (timeoutMinutes < 60) return 'Через $timeoutMinutes мин';
    final h = timeoutMinutes ~/ 60;
    final m = timeoutMinutes % 60;
    if (m == 0) return 'Через $h ч';
    return 'Через $h ч $m мин';
  }
}