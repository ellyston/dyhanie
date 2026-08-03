import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Новый стиль иконок:
/// 1) ключ в [catalog]
/// 2) ветка в [_pick]
/// Новая иконка приложения: геттер в [AppIcons]
class IconStyleService {
  static const prefKey = 'app_icon_style';
  static const defaultCode = 'outlined';

  static const Map<String, String> catalog = {
    'outlined': 'Outlined',
    'rounded': 'Rounded',
    'sharp': 'Sharp',
  };

  static String _code = defaultCode;
  static String get code => _code;

  static Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(prefKey);
    if (saved != null && catalog.containsKey(saved)) {
      _code = saved;
    }
  }

  static Future<void> setCode(String code) async {
    if (!catalog.containsKey(code)) return;
    _code = code;
    final p = await SharedPreferences.getInstance();
    await p.setString(prefKey, code);
  }

  static String label(String code) => catalog[code] ?? code;
}

class AppIcons {
  static IconData pick(IconData outlined, IconData rounded, IconData sharp) {
    switch (IconStyleService.code) {
      case 'rounded':
        return rounded;
      case 'sharp':
        return sharp;
      default:
        return outlined;
    }
  }

  static IconData get settings =>
      pick(Icons.settings_outlined, Icons.settings_rounded, Icons.settings_sharp);

  static IconData get logout =>
      pick(Icons.logout_outlined, Icons.logout_rounded, Icons.logout_sharp);

  static IconData get timer =>
      pick(Icons.timer_outlined, Icons.timer_rounded, Icons.timer_sharp);

  static IconData get clean => pick(
        Icons.cleaning_services_outlined,
        Icons.cleaning_services_rounded,
        Icons.cleaning_services_sharp,
      );

  static IconData get shield =>
      pick(Icons.shield_outlined, Icons.shield_rounded, Icons.shield_sharp);

  static IconData get chat =>
      pick(Icons.chat_bubble_outline, Icons.chat_rounded, Icons.chat_sharp);

  static IconData get contacts =>
      pick(Icons.contacts_outlined, Icons.contacts_rounded, Icons.contacts_sharp);

  static IconData get add =>
      pick(Icons.add_outlined, Icons.add_rounded, Icons.add_sharp);

  static IconData get login =>
      pick(Icons.login_outlined, Icons.login_rounded, Icons.login_sharp);

  static IconData get language =>
      pick(Icons.language_outlined, Icons.language, Icons.language_sharp);

  static IconData get info =>
      pick(Icons.info_outline, Icons.info_rounded, Icons.info_sharp);

  static IconData get help =>
      pick(Icons.help_outline, Icons.help_rounded, Icons.help_sharp);

  static IconData get privacy => pick(
        Icons.privacy_tip_outlined,
        Icons.privacy_tip_rounded,
        Icons.privacy_tip_sharp,
      );

  static IconData get battery => pick(
        Icons.battery_saver_outlined,
        Icons.battery_saver_rounded,
        Icons.battery_saver_sharp,
      );

  static IconData get font =>
      pick(Icons.text_fields_outlined, Icons.text_fields, Icons.text_fields_sharp);

  static IconData get iconsStyle =>
      pick(Icons.apps_outlined, Icons.apps_rounded, Icons.apps_sharp);

  static IconData get theme =>
      pick(Icons.brightness_6_outlined, Icons.brightness_6, Icons.brightness_6_sharp);

  static IconData get chevron =>
      pick(Icons.chevron_right, Icons.chevron_right_rounded, Icons.chevron_right_sharp);
    
  static IconData get note => pick(
        Icons.note_alt_outlined,
        Icons.note_alt_rounded,
        Icons.note_alt_sharp,
      );

  static IconData get sound => pick(
        Icons.volume_up_outlined,
        Icons.volume_up_rounded,
        Icons.volume_up_sharp,
      );

  static IconData get delete => pick(
        Icons.delete_outline,
        Icons.delete_rounded,
        Icons.delete_sharp,
      );

  static IconData get block => pick(
        Icons.block_outlined,
        Icons.block_flipped, // fallback, if no rounded
        Icons.block_sharp,
      );

  static IconData get pin => pick(
        Icons.push_pin_outlined,
        Icons.push_pin_rounded,
        Icons.push_pin_sharp,
      );

  static IconData get more => pick(
        Icons.more_vert_outlined,
        Icons.more_vert_rounded,
        Icons.more_vert,
      );

}