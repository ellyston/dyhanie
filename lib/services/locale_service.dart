import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const prefKey = 'app_locale';
  static const defaultCode = 'ru';

  /// ru — русский, en — English, de_ch — швейцарский (Deutsch CH)
  static const supported = ['ru', 'en', 'de_ch'];

  static String _code = defaultCode;

  static String get code => _code;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefKey);
    if (saved != null && supported.contains(saved)) {
      _code = saved;
    } else {
      _code = defaultCode;
    }
  }

  static Future<void> setCode(String code) async {
    if (!supported.contains(code)) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, code);
  }

  static String t(String key) {
    return _dict[_code]?[key] ??
        _dict[defaultCode]?[key] ??
        key;
  }

  static String tParams(String key, Map<String, String> params) {
    var s = t(key);
    params.forEach((k, v) {
      s = s.replaceAll('{$k}', v);
    });
    return s;
  }

  /// Название языка в нативной форме (как в системных настройках)
  static String languageName(String code) {
    return switch (code) {
      'ru' => 'Русский',
      'en' => 'English',
      'de_ch' => 'Deutsch (Schweiz)',
      _ => code,
    };
  }

  static const Map<String, Map<String, String>> _dict = {
    // ───────── Русский ─────────
    'ru': {
      'settings': 'Настройки',
      'support': 'Поддержка',
      'app_section': 'Приложение',
      'about_section': 'О приложении',
      'ask_question': 'Задать вопрос',
      'ask_question_sub': 'Написать в поддержку',
      'privacy_policy': 'Политика конфиденциальности',
      'privacy_policy_sub': 'Как мы обрабатываем данные',
      'energy_saving': 'Энергосбережение',
      'energy_saving_sub': 'Фон, сеть, анимации',
      'language': 'Язык',
      'about': 'О приложении',
      'about_sub': 'Дыхание · 0.1.0',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'continue': 'Продолжить',
      'yes': 'Да',
      'no': 'Нет',
      'ok': 'OK',
      'send': 'Отправить',
      'chats': 'Чаты',
      'contacts': 'Контакты',
      'profile': 'Профиль',
      'create_room': 'Создать комнату',
      'join_by_code': 'Войти по коду',
      'saved_chats': 'Сохранённые чаты',
      'language_saved': 'Язык сохранён',
      'language_restart_hint': 'Интерфейс обновлён',
      'ask_hint':
          'Опишите проблему или вопрос. Откроется почтовое приложение.',
      'ask_placeholder': 'Ваш вопрос…',
      'ask_empty': 'Напишите вопрос',
      'ask_mail_fail': 'Не удалось открыть почту',
      'energy_hint':
          'Настройки влияют на расход батареи. Часть опций применится после перезапуска экранов.',
      'less_animations': 'Меньше анимаций',
      'less_animations_sub': 'Отключить лишние переходы и эффекты',
      'pause_vpn_bg': 'Пауза VPN в фоне',
      'pause_vpn_bg_sub':
          'Не держать туннель активно при свёрнутом приложении',
      'less_presence': 'Реже обновлять online',
      'less_presence_sub': 'Снизить частоту presence-сигналов',
    },

    // ───────── English ─────────
    'en': {
      'settings': 'Settings',
      'support': 'Support',
      'app_section': 'App',
      'about_section': 'About',
      'ask_question': 'Ask a question',
      'ask_question_sub': 'Contact support',
      'privacy_policy': 'Privacy policy',
      'privacy_policy_sub': 'How we handle data',
      'energy_saving': 'Energy saving',
      'energy_saving_sub': 'Background, network, animations',
      'language': 'Language',
      'about': 'About',
      'about_sub': 'Dyhanie · 0.1.0',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'continue': 'Continue',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
      'send': 'Send',
      'chats': 'Chats',
      'contacts': 'Contacts',
      'profile': 'Profile',
      'create_room': 'Create room',
      'join_by_code': 'Join by code',
      'saved_chats': 'Saved chats',
      'language_saved': 'Language saved',
      'language_restart_hint': 'Interface updated',
      'ask_hint': 'Describe your issue. Your mail app will open.',
      'ask_placeholder': 'Your question…',
      'ask_empty': 'Please write a question',
      'ask_mail_fail': 'Could not open mail',
      'energy_hint':
          'These options affect battery use. Some apply after reopening screens.',
      'less_animations': 'Fewer animations',
      'less_animations_sub': 'Disable extra transitions and effects',
      'pause_vpn_bg': 'Pause VPN in background',
      'pause_vpn_bg_sub':
          'Do not keep the tunnel active when the app is minimized',
      'less_presence': 'Less frequent online updates',
      'less_presence_sub': 'Reduce presence signal frequency',
    },

    // ───────── Deutsch (Schweiz) ─────────
    'de_ch': {
      'settings': 'Einstellungen',
      'support': 'Support',
      'app_section': 'App',
      'about_section': 'Über die App',
      'ask_question': 'Frage stellen',
      'ask_question_sub': 'Support kontaktieren',
      'privacy_policy': 'Datenschutz',
      'privacy_policy_sub': 'Wie wir Daten verarbeiten',
      'energy_saving': 'Energiesparen',
      'energy_saving_sub': 'Hintergrund, Netzwerk, Animationen',
      'language': 'Sprache',
      'about': 'Über die App',
      'about_sub': 'Dyhanie · 0.1.0',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'delete': 'Löschen',
      'continue': 'Weiter',
      'yes': 'Ja',
      'no': 'Nein',
      'ok': 'OK',
      'send': 'Senden',
      'chats': 'Chats',
      'contacts': 'Kontakte',
      'profile': 'Profil',
      'create_room': 'Raum erstellen',
      'join_by_code': 'Mit Code beitreten',
      'saved_chats': 'Gespeicherte Chats',
      'language_saved': 'Sprache gespeichert',
      'language_restart_hint': 'Oberfläche aktualisiert',
      'ask_hint':
          'Beschreibe dein Anliegen. Die Mail-App wird geöffnet.',
      'ask_placeholder': 'Deine Frage…',
      'ask_empty': 'Bitte eine Frage eingeben',
      'ask_mail_fail': 'Mail konnte nicht geöffnet werden',
      'energy_hint':
          'Diese Optionen beeinflussen den Akkuverbrauch. Einige gelten nach dem erneuten Öffnen der Screens.',
      'less_animations': 'Weniger Animationen',
      'less_animations_sub': 'Zusätzliche Übergänge und Effekte deaktivieren',
      'pause_vpn_bg': 'VPN im Hintergrund pausieren',
      'pause_vpn_bg_sub':
          'Tunnel nicht aktiv halten, wenn die App minimiert ist',
      'less_presence': 'Online seltener aktualisieren',
      'less_presence_sub': 'Presence-Signale seltener senden',
    },
  };
}

/// Короткий алиас для UI
class L {
  static String t(String key) => LocaleService.t(key);

  static String tParams(String key, Map<String, String> p) =>
      LocaleService.tParams(key, p);
}