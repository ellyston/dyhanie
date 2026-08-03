import 'package:shared_preferences/shared_preferences.dart';

class AccountResetService {
  /// Локальный сброс перед «новым» устройством после restore.
  static Future<void> resetLocalAccount({bool markRestored = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // профиль
    await prefs.remove('username');
    await prefs.remove('avatar');

    // пин / блокировка (чтобы заново «Придумайте PIN»)
    await prefs.remove('pin_code');
    await prefs.remove('pin_hash');
    await prefs.remove('pin_enabled');
    // если у вас другие ключи PIN — добавьте сюда те же, что пишет PinSetupScreen

    // чаты / заметки (по желанию; для «новое устройство» логично чистить)
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      if (k.startsWith('chat_history_') ||
          k.startsWith('chat_cfg_') ||
          k == 'chats_pinned' ||
          k == 'chats_notes') {
        await prefs.remove(k);
      }
    }

    if (markRestored) {
      await prefs.setBool('recovery_phrase_shown', true);
      await prefs.setBool('identity_restored_stub', true);
    }
  }
}