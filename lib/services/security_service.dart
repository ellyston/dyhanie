import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const _pinKey = 'app_pin';
  static const _pinSetKey = 'pin_set';
  static const _lockMinutesKey = 'lock_timeout_minutes';
  static const _lastActiveKey = 'last_active_ts';
  static const _unlockedKey = 'session_unlocked';

  /// 0 = никогда не блокировать
  static const lockOptionsMinutes = [5, 15, 30, 60, 120, 360, 0];

  Future<bool> isPinSet() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_pinSetKey) == true && (p.getString(_pinKey)?.length == 4);
  }

  Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pinKey, pin);
    await p.setBool(_pinSetKey, true);
    await markUnlocked();
  }

  Future<bool> checkPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_pinKey) == pin;
  }

  Future<int> getLockTimeoutMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_lockMinutesKey) ?? 5;
  }

  Future<void> setLockTimeoutMinutes(int minutes) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_lockMinutesKey, minutes);
  }

  Future<void> markUnlocked() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_unlockedKey, true);
    await p.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> markActive() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> lockNow() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_unlockedKey, false);
  }

  /// Нужно ли показать PIN при входе
  Future<bool> needsLockScreen() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_pinSetKey) != true) return false;

    final timeout = p.getInt(_lockMinutesKey) ?? 5;
    if (timeout == 0) {
      // никогда — только если явно заблокировали
      return p.getBool(_unlockedKey) != true;
    }

    final last = p.getInt(_lastActiveKey) ?? 0;
    final elapsedMin =
        (DateTime.now().millisecondsSinceEpoch - last) / 60000.0;
    if (elapsedMin >= timeout) {
      await p.setBool(_unlockedKey, false);
      return true;
    }
    return p.getBool(_unlockedKey) != true;
  }

  /// Очистить кэш: временные сообщения, outbox, фоны, локальные чаты
  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();

    // сохраняем аккаунт и безопасность
    final pin = p.getString(_pinKey);
    final pinSet = p.getBool(_pinSetKey);
    final lock = p.getInt(_lockMinutesKey);
    final user = p.getString('username');
    final avatar = p.getString('avatar');
    final contacts = p.getStringList('contacts');
    final notes = p.getString('contact_notes');
    final sounds = p.getString('contact_sounds');

    await p.clear();

    if (pin != null) await p.setString(_pinKey, pin);
    if (pinSet != null) await p.setBool(_pinSetKey, pinSet);
    if (lock != null) await p.setInt(_lockMinutesKey, lock);
    if (user != null) await p.setString('username', user);
    if (avatar != null) await p.setString('avatar', avatar);
    if (contacts != null) await p.setStringList('contacts', contacts);
    if (notes != null) await p.setString('contact_notes', notes);
    if (sounds != null) await p.setString('contact_sounds', sounds);

    await markUnlocked();
  }

  /// Полное удаление локальных данных приложения
  Future<void> wipeEverything() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }

  String lockLabel(int minutes) {
    if (minutes == 0) return 'Никогда';
    if (minutes < 60) return '$minutes мин';
    final h = minutes ~/ 60;
    return '$h ч';
  }
}