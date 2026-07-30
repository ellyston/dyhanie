import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const prefKey = 'app_locale';
  static const defaultCode = 'ru';

  /// ru — русский, en — English, de_ch — Deutsch (Schweiz)
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

  static String languageName(String code) {
    return switch (code) {
      'ru' => 'Русский',
      'en' => 'English',
      'de_ch' => 'Deutsch (Schweiz)',
      _ => code,
    };
  }

  static const Map<String, Map<String, String>> _dict = {
    // ═══════════════════════════════════════
    // РУССКИЙ
    // ═══════════════════════════════════════
    'ru': {
      // common
      'app_name': 'Дыхание',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'continue': 'Продолжить',
      'yes': 'Да',
      'no': 'Нет',
      'ok': 'OK',
      'send': 'Отправить',
      'close': 'Закрыть',
      'back': 'Назад',
      'search': 'Поиск',
      'done': 'Готово',
      'error': 'Ошибка',
      'loading': 'Загрузка…',
      'online': 'онлайн',
      'offline': 'оффлайн',
      'you': 'Вы',
      'clear': 'Очистить',

      // settings
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
      'language_saved': 'Язык сохранён',
      'language_restart_hint': 'Интерфейс обновлён',

      // ask question
      'ask_hint':
          'Опишите проблему или вопрос. Откроется почтовое приложение.',
      'ask_placeholder': 'Ваш вопрос…',
      'ask_empty': 'Напишите вопрос',
      'ask_mail_fail': 'Не удалось открыть почту',

      // energy
      'energy_hint':
          'Настройки влияют на расход батареи. Часть опций применится после перезапуска экранов.',
      'less_animations': 'Меньше анимаций',
      'less_animations_sub': 'Отключить лишние переходы и эффекты',
      'pause_vpn_bg': 'Пауза VPN в фоне',
      'pause_vpn_bg_sub':
          'Не держать туннель активно при свёрнутом приложении',
      'less_presence': 'Реже обновлять online',
      'less_presence_sub': 'Снизить частоту presence-сигналов',

      // home
      'profile': 'Профиль',
      'create_room': 'Создать комнату',
      'join_by_code': 'Войти по коду',
      'saved_chats': 'Сохранённые чаты',
      'contacts': 'Контакты',
      'chats': 'Чаты',
      'auto_lock': 'Автоблокировка',
      'clear_cache': 'Очистить кэш',
      'clear_cache_title': 'Очистить кэш?',
      'clear_cache_body':
          'Удалятся временные сообщения и локальные черновики. Аккаунт останется.',
      'cache_cleared': 'Кэш очищен',
      'vpn': 'VPN',

      // chats list
      'chats_empty': 'Пока нет диалогов.\nНапишите из Контактов.',
      'chats_empty_saved':
          'Пока нет диалогов.\nСохраните чат (зелёный режим)\nили напишите из Контактов.',
      'waiting_in_chat': 'Ждут вас в чате',
      'incoming_count': 'Есть входящие: {n}',
      'outbox_waiting': 'Исходящие ждут открытия',
      'dialog': 'Диалог',
      'saved_dialog': 'Сохранённый диалог',
      'pinned_chat': 'Закреплённый чат',
      'pin_chat': 'Закрепить',
      'unpin_chat': 'Открепить',
      'pin_limit': 'Можно закрепить максимум {n} чатов',
      'delete_chat': 'Удалить чат',
      'delete_chat_title': 'Удалить чат?',
      'delete_chat_body':
          'Диалог с @{name} будет удалён с этого устройства.\nИстория и исходящая очередь очистятся.',
      'chat_deleted': 'Чат удалён',
      'pinned_count': 'Закреплено {n}/{max}',

      // contacts
      'contacts_title': 'Контакты',
      'local_search': 'Поиск в контактах',
      'global_search': 'Найти по username',
      'send_invite': 'Пригласить',
      'incoming_invites': 'Входящие приглашения',
      'outgoing_invites': 'Исходящие',
      'accept': 'Принять',
      'decline': 'Отклонить',
      'cancel_invite': 'Отменить',
      'write_message': 'Написать',
      'block': 'Заблокировать',
      'unblock': 'Разблокировать',
      'blacklist': 'Чёрный список',
      'already_contact': 'Уже в контактах',
      'user_not_found': 'Пользователь не найден',
      'invite_sent': 'Приглашение отправлено',
      'invite_self': 'Это вы',
      'empty_username': 'Пустой username',
      'blocked_user': 'Пользователь в чёрном списке',
      'no_contacts': 'Нет контактов',
      'add_from_search': 'Найдите человека по username выше',

      // profile
      'edit_profile': 'Профиль',
      'change_avatar': 'Сменить',
      'username': 'username',
      'delete_all': 'Удалить всё',
      'delete_all_title': 'Удалить все данные?',
      'delete_all_body':
          'Будут стёрты профиль, контакты, чаты и настройки на этом устройстве.',
      'username_invalid': 'Некорректный username',
      'username_hint': 'Только маленькие английские буквы и цифры',
      'username_min': 'Минимум 3 символа',
      'enter_username': 'Введите имя пользователя',
      'create_profile': 'Создай профиль',
      'pick_avatar': 'Нажми, чтобы выбрать аватар',

      // welcome / splash
      'ephemeral_talks': 'Эфемерные разговоры',
      'tagline_button': 'ГОВОРИ ПОКА ДЫШИШЬ',
      'speak_while_breathe': 'Говори пока дышишь',

      // pin
      'pin_setup': 'Создайте PIN',
      'pin_confirm': 'Повторите PIN',
      'pin_lock': 'Введите PIN',
      'pin_wrong': 'Неверный PIN',
      'pin_mismatch': 'PIN не совпадает',
      'pin_set': 'PIN установлен',

      // auto-lock
      'auto_lock_title': 'Автоблокировка',
      'lock_on_minimize': 'При сворачивании',
      'lock_after_time': 'Через время',
      'never': 'Никогда',
      'minutes_1': '1 минута',
      'minutes_5': '5 минут',
      'minutes_15': '15 минут',
      'minutes_30': '30 минут',
      'hours_1': '1 час',

      // join room
      'join_room': 'Войти по коду',
      'room_code': 'Код комнаты',
      'enter_code': 'Введите код',
      'join': 'Войти',
      'invalid_code': 'Некорректный код',

      // chat
      'message_hint': 'Сообщение…',
      'typing': 'печатает…',
      'reply': 'Ответить',
      'copy': 'Копировать',
      'delete_for_me': 'Удалить у себя',
      'delete_for_all': 'Удалить у всех',
      'pin_message': 'Закрепить',
      'unpin_message': 'Открепить',
      'search_messages': 'Поиск',
      'ttl': 'Время жизни',
      'ttl_none': 'Не исчезать',
      'sec_5': '5 сек',
      'sec_10': '10 сек',
      'sec_15': '15 сек',
      'sec_30': '30 сек',
      'min_1': '1 мин',
      'min_2': '2 мин',
      'min_5': '5 мин',
      'min_10': '10 мин',
      'attach': 'Вложение',
      'background': 'Фон',
      'font_size': 'Размер шрифта',
      'suggest_save': 'Предложить сохранить чат',
      'save_chat_offer': '@{name} предлагает сохранить чат',
      'exit_chat': 'Выйти?',
      'exit_wipe': 'Диалог будет полностью очищен (сервер и P2P).',
      'exit_keep': 'Диалог сохранится.',
      'wipe_on_exit': 'При выходе диалог будет полностью очищен',
      'keep_on_exit': 'При выходе диалог сохранится',
      'waiting_p2p': 'Ждём P2P',
      'p2p_connected': 'P2P',
      'via_server': 'Сервер',
      'call': 'Звонок',
      'incoming_call': 'Входящий звонок',
      'outgoing_call': 'Исходящий звонок',
      'call_ended': 'Звонок завершён',
      'mute': 'Без звука',
      'speaker': 'Динамик',
      'decline_call': 'Отклонить',
      'accept_call': 'Принять',
      'end_call': 'Завершить',
      'connecting': 'Подключение…',
      'no_messages': 'Нет сообщений',
      'photo': 'фото',

      // vpn
      'vpn_title': 'VPN',
      'vpn_connect': 'Подключить',
      'vpn_disconnect': 'Отключить',
      'vpn_connecting': 'Подключение…',
      'vpn_no_configs': 'Нет конфигураций',
      'vpn_add': 'Добавить',
      'vpn_import_file': 'Импорт из файла',
      'vpn_import_url': 'По ссылке',
      'vpn_import_qr': 'Сканировать QR',
      'vpn_manual': 'Вручную',
      'vpn_other_active': 'Другой VPN уже активен',
      'vpn_all_down':
          'Не удалось подключиться. Возможно, подписка устарела или заблокирована. Попробуйте обновить её.',
      'vpn_check_ping': 'Проверить пинг',
      'vpn_refresh': 'Обновить',
      'vpn_refresh_all': 'Обновить все',
      'vpn_auto': 'Авто',
      'vpn_manual_select': 'Ручной',
      'vpn_slots': 'Слоты',
      'vpn_delete_slot': 'Удалить слот',
      
      'waiting_peer': 'Ожидание собеседника...',
      'quiet_chat': 'Пока тихо',
      'emoji': 'Эмодзи',
      'add_emoji': 'Добавить эмодзи',
    },

    // ═══════════════════════════════════════
    // ENGLISH
    // ═══════════════════════════════════════
    'en': {
      'app_name': 'Dyhanie',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'continue': 'Continue',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
      'send': 'Send',
      'close': 'Close',
      'back': 'Back',
      'search': 'Search',
      'done': 'Done',
      'error': 'Error',
      'loading': 'Loading…',
      'online': 'online',
      'offline': 'offline',
      'you': 'You',
      'clear': 'Clear',

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

      'profile': 'Profile',
      'create_room': 'Create room',
      'join_by_code': 'Join by code',
      'saved_chats': 'Saved chats',
      'contacts': 'Contacts',
      'chats': 'Chats',
      'auto_lock': 'Auto-lock',
      'clear_cache': 'Clear cache',
      'clear_cache_title': 'Clear cache?',
      'clear_cache_body':
          'Temporary messages and local drafts will be removed. Your account stays.',
      'cache_cleared': 'Cache cleared',
      'vpn': 'VPN',

      'chats_empty': 'No chats yet.\nMessage someone from Contacts.',
      'chats_empty_saved':
          'No chats yet.\nSave a chat (green mode)\nor message from Contacts.',
      'waiting_in_chat': 'Waiting for you in chat',
      'incoming_count': 'Incoming: {n}',
      'outbox_waiting': 'Outgoing waiting to open',
      'dialog': 'Chat',
      'saved_dialog': 'Saved chat',
      'pinned_chat': 'Pinned chat',
      'pin_chat': 'Pin',
      'unpin_chat': 'Unpin',
      'pin_limit': 'You can pin up to {n} chats',
      'delete_chat': 'Delete chat',
      'delete_chat_title': 'Delete chat?',
      'delete_chat_body':
          'Chat with @{name} will be removed from this device.\nHistory and outbox will be cleared.',
      'chat_deleted': 'Chat deleted',
      'pinned_count': 'Pinned {n}/{max}',

      'contacts_title': 'Contacts',
      'local_search': 'Search contacts',
      'global_search': 'Find by username',
      'send_invite': 'Invite',
      'incoming_invites': 'Incoming invites',
      'outgoing_invites': 'Outgoing',
      'accept': 'Accept',
      'decline': 'Decline',
      'cancel_invite': 'Cancel',
      'write_message': 'Message',
      'block': 'Block',
      'unblock': 'Unblock',
      'blacklist': 'Blocked',
      'already_contact': 'Already in contacts',
      'user_not_found': 'User not found',
      'invite_sent': 'Invite sent',
      'invite_self': 'That\'s you',
      'empty_username': 'Empty username',
      'blocked_user': 'User is blocked',
      'no_contacts': 'No contacts',
      'add_from_search': 'Find someone by username above',

      'edit_profile': 'Profile',
      'change_avatar': 'Change',
      'username': 'username',
      'delete_all': 'Delete everything',
      'delete_all_title': 'Delete all data?',
      'delete_all_body':
          'Profile, contacts, chats and settings on this device will be erased.',
      'username_invalid': 'Invalid username',
      'username_hint': 'Only lowercase English letters and digits',
      'username_min': 'At least 3 characters',
      'enter_username': 'Enter username',
      'create_profile': 'Create profile',
      'pick_avatar': 'Tap to choose avatar',

      'ephemeral_talks': 'Ephemeral conversations',
      'tagline_button': 'SPEAK WHILE YOU BREATHE',
      'speak_while_breathe': 'Speak while you breathe',

      'pin_setup': 'Create PIN',
      'pin_confirm': 'Confirm PIN',
      'pin_lock': 'Enter PIN',
      'pin_wrong': 'Wrong PIN',
      'pin_mismatch': 'PINs do not match',
      'pin_set': 'PIN set',

      'auto_lock_title': 'Auto-lock',
      'lock_on_minimize': 'On minimize',
      'lock_after_time': 'After time',
      'never': 'Never',
      'minutes_1': '1 minute',
      'minutes_5': '5 minutes',
      'minutes_15': '15 minutes',
      'minutes_30': '30 minutes',
      'hours_1': '1 hour',

      'join_room': 'Join by code',
      'room_code': 'Room code',
      'enter_code': 'Enter code',
      'join': 'Join',
      'invalid_code': 'Invalid code',

      'message_hint': 'Message…',
      'typing': 'typing…',
      'reply': 'Reply',
      'copy': 'Copy',
      'delete_for_me': 'Delete for me',
      'delete_for_all': 'Delete for everyone',
      'pin_message': 'Pin',
      'unpin_message': 'Unpin',
      'search_messages': 'Search',
      'ttl': 'Time to live',
      'ttl_none': 'Don\'t disappear',
      'sec_5': '5 sec',
      'sec_10': '10 sec',
      'sec_15': '15 sec',
      'sec_30': '30 sec',
      'min_1': '1 min',
      'min_2': '2 min',
      'min_5': '5 min',
      'min_10': '10 min',
      'attach': 'Attachment',
      'background': 'Background',
      'font_size': 'Font size',
      'suggest_save': 'Suggest saving chat',
      'save_chat_offer': '@{name} suggests saving the chat',
      'exit_chat': 'Leave?',
      'exit_wipe': 'The chat will be fully cleared (server and P2P).',
      'exit_keep': 'The chat will be kept.',
      'wipe_on_exit': 'Chat will be fully cleared on exit',
      'keep_on_exit': 'Chat will be kept on exit',
      'waiting_p2p': 'Waiting for P2P',
      'p2p_connected': 'P2P',
      'via_server': 'Server',
      'call': 'Call',
      'incoming_call': 'Incoming call',
      'outgoing_call': 'Outgoing call',
      'call_ended': 'Call ended',
      'mute': 'Mute',
      'speaker': 'Speaker',
      'decline_call': 'Decline',
      'accept_call': 'Accept',
      'end_call': 'End',
      'connecting': 'Connecting…',
      'no_messages': 'No messages',
      'photo': 'photo',

      'vpn_title': 'VPN',
      'vpn_connect': 'Connect',
      'vpn_disconnect': 'Disconnect',
      'vpn_connecting': 'Connecting…',
      'vpn_no_configs': 'No configurations',
      'vpn_add': 'Add',
      'vpn_import_file': 'Import from file',
      'vpn_import_url': 'From link',
      'vpn_import_qr': 'Scan QR',
      'vpn_manual': 'Manual',
      'vpn_other_active': 'Another VPN is already active',
      'vpn_all_down':
          'Could not connect. Subscription may be outdated or blocked. Try refreshing it.',
      'vpn_check_ping': 'Check ping',
      'vpn_refresh': 'Refresh',
      'vpn_refresh_all': 'Refresh all',
      'vpn_auto': 'Auto',
      'vpn_manual_select': 'Manual',
      'vpn_slots': 'Slots',
      'vpn_delete_slot': 'Delete slot',

      'waiting_peer': 'Waiting for peer...',
      'quiet_chat': 'Quiet for now',
      'emoji': 'Emoji',
      'add_emoji': 'Add emoji',
    },

    // ═══════════════════════════════════════
    // DEUTSCH (SCHWEIZ)
    // ═══════════════════════════════════════
    'de_ch': {
      'app_name': 'Dyhanie',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'delete': 'Löschen',
      'continue': 'Weiter',
      'yes': 'Ja',
      'no': 'Nein',
      'ok': 'OK',
      'send': 'Senden',
      'close': 'Schliessen',
      'back': 'Zurück',
      'search': 'Suche',
      'done': 'Fertig',
      'error': 'Fehler',
      'loading': 'Laden…',
      'online': 'online',
      'offline': 'offline',
      'you': 'Du',
      'clear': 'Leeren',

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

      'profile': 'Profil',
      'create_room': 'Raum erstellen',
      'join_by_code': 'Mit Code beitreten',
      'saved_chats': 'Gespeicherte Chats',
      'contacts': 'Kontakte',
      'chats': 'Chats',
      'auto_lock': 'Autosperre',
      'clear_cache': 'Cache leeren',
      'clear_cache_title': 'Cache leeren?',
      'clear_cache_body':
          'Temporäre Nachrichten und lokale Entwürfe werden gelöscht. Das Konto bleibt.',
      'cache_cleared': 'Cache geleert',
      'vpn': 'VPN',

      'chats_empty': 'Noch keine Chats.\nSchreibe über Kontakte.',
      'chats_empty_saved':
          'Noch keine Chats.\nChat speichern (grüner Modus)\noder über Kontakte schreiben.',
      'waiting_in_chat': 'Warten im Chat auf dich',
      'incoming_count': 'Eingehend: {n}',
      'outbox_waiting': 'Ausgehend wartet auf Öffnen',
      'dialog': 'Chat',
      'saved_dialog': 'Gespeicherter Chat',
      'pinned_chat': 'Angehefteter Chat',
      'pin_chat': 'Anheften',
      'unpin_chat': 'Lösen',
      'pin_limit': 'Maximal {n} Chats anheften',
      'delete_chat': 'Chat löschen',
      'delete_chat_title': 'Chat löschen?',
      'delete_chat_body':
          'Chat mit @{name} wird auf diesem Gerät gelöscht.\nVerlauf und Outbox werden geleert.',
      'chat_deleted': 'Chat gelöscht',
      'pinned_count': 'Angeheftet {n}/{max}',

      'contacts_title': 'Kontakte',
      'local_search': 'Kontakte suchen',
      'global_search': 'Per Username finden',
      'send_invite': 'Einladen',
      'incoming_invites': 'Eingehende Einladungen',
      'outgoing_invites': 'Ausgehend',
      'accept': 'Annehmen',
      'decline': 'Ablehnen',
      'cancel_invite': 'Abbrechen',
      'write_message': 'Schreiben',
      'block': 'Blockieren',
      'unblock': 'Entsperren',
      'blacklist': 'Blockiert',
      'already_contact': 'Bereits in Kontakten',
      'user_not_found': 'Benutzer nicht gefunden',
      'invite_sent': 'Einladung gesendet',
      'invite_self': 'Das bist du',
      'empty_username': 'Leerer Username',
      'blocked_user': 'Benutzer ist blockiert',
      'no_contacts': 'Keine Kontakte',
      'add_from_search': 'Person oben per Username suchen',

      'edit_profile': 'Profil',
      'change_avatar': 'Ändern',
      'username': 'username',
      'delete_all': 'Alles löschen',
      'delete_all_title': 'Alle Daten löschen?',
      'delete_all_body':
          'Profil, Kontakte, Chats und Einstellungen auf diesem Gerät werden gelöscht.',
      'username_invalid': 'Ungültiger Username',
      'username_hint': 'Nur kleine englische Buchstaben und Ziffern',
      'username_min': 'Mindestens 3 Zeichen',
      'enter_username': 'Username eingeben',
      'create_profile': 'Profil erstellen',
      'pick_avatar': 'Tippen, um Avatar zu wählen',

      'ephemeral_talks': 'Vergängliche Gespräche',
      'tagline_button': 'SPRICH SOLANGE DU ATMEST',
      'speak_while_breathe': 'Sprich solange du atmest',

      'pin_setup': 'PIN erstellen',
      'pin_confirm': 'PIN bestätigen',
      'pin_lock': 'PIN eingeben',
      'pin_wrong': 'Falscher PIN',
      'pin_mismatch': 'PINs stimmen nicht überein',
      'pin_set': 'PIN gesetzt',

      'auto_lock_title': 'Autosperre',
      'lock_on_minimize': 'Beim Minimieren',
      'lock_after_time': 'Nach Zeit',
      'never': 'Nie',
      'minutes_1': '1 Minute',
      'minutes_5': '5 Minuten',
      'minutes_15': '15 Minuten',
      'minutes_30': '30 Minuten',
      'hours_1': '1 Stunde',

      'join_room': 'Mit Code beitreten',
      'room_code': 'Raumcode',
      'enter_code': 'Code eingeben',
      'join': 'Beitreten',
      'invalid_code': 'Ungültiger Code',

      'message_hint': 'Nachricht…',
      'typing': 'schreibt…',
      'reply': 'Antworten',
      'copy': 'Kopieren',
      'delete_for_me': 'Für mich löschen',
      'delete_for_all': 'Für alle löschen',
      'pin_message': 'Anheften',
      'unpin_message': 'Lösen',
      'search_messages': 'Suche',
      'ttl': 'Lebensdauer',
      'ttl_none': 'Nicht verschwinden',
      'sec_5': '5 Sek',
      'sec_10': '10 Sek',
      'sec_15': '15 Sek',
      'sec_30': '30 Sek',
      'min_1': '1 Min',
      'min_2': '2 Min',
      'min_5': '5 Min',
      'min_10': '10 Min',
      'attach': 'Anhang',
      'background': 'Hintergrund',
      'font_size': 'Schriftgrösse',
      'suggest_save': 'Chat speichern vorschlagen',
      'save_chat_offer': '@{name} schlägt vor, den Chat zu speichern',
      'exit_chat': 'Verlassen?',
      'exit_wipe': 'Der Chat wird vollständig gelöscht (Server und P2P).',
      'exit_keep': 'Der Chat bleibt erhalten.',
      'wipe_on_exit': 'Chat wird beim Verlassen vollständig gelöscht',
      'keep_on_exit': 'Chat bleibt beim Verlassen erhalten',
      'waiting_p2p': 'Warte auf P2P',
      'p2p_connected': 'P2P',
      'via_server': 'Server',
      'call': 'Anruf',
      'incoming_call': 'Eingehender Anruf',
      'outgoing_call': 'Ausgehender Anruf',
      'call_ended': 'Anruf beendet',
      'mute': 'Stumm',
      'speaker': 'Lautsprecher',
      'decline_call': 'Ablehnen',
      'accept_call': 'Annehmen',
      'end_call': 'Beenden',
      'connecting': 'Verbinden…',
      'no_messages': 'Keine Nachrichten',
      'photo': 'Foto',

      'vpn_title': 'VPN',
      'vpn_connect': 'Verbinden',
      'vpn_disconnect': 'Trennen',
      'vpn_connecting': 'Verbinden…',
      'vpn_no_configs': 'Keine Konfigurationen',
      'vpn_add': 'Hinzufügen',
      'vpn_import_file': 'Aus Datei importieren',
      'vpn_import_url': 'Per Link',
      'vpn_import_qr': 'QR scannen',
      'vpn_manual': 'Manuell',
      'vpn_other_active': 'Ein anderes VPN ist bereits aktiv',
      'vpn_all_down':
          'Verbindung fehlgeschlagen. Abo veraltet oder blockiert. Bitte aktualisieren.',
      'vpn_check_ping': 'Ping prüfen',
      'vpn_refresh': 'Aktualisieren',
      'vpn_refresh_all': 'Alle aktualisieren',
      'vpn_auto': 'Auto',
      'vpn_manual_select': 'Manuell',
      'vpn_slots': 'Slots',
      'vpn_delete_slot': 'Slot löschen',

      'waiting_peer': 'Warte auf Gesprächspartner...',
      'quiet_chat': 'Noch still',
      'emoji': 'Emoji',
      'add_emoji': 'Emoji hinzufügen',
    },
  };
}

class L {
  static String t(String key) => LocaleService.t(key);

  static String tParams(String key, Map<String, String> p) =>
      LocaleService.tParams(key, p);
}