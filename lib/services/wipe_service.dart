import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'security_service.dart';

/// Полная очистка следов приложения.
/// Сюда позже добавим: Firebase, файлы на диске, Android uninstall intent и т.д.
class WipeService {
  final SecurityService _security = SecurityService();

  /// Результат попытки полного удаления
  /// [localCleared] — локальные данные стёрты
  /// [message] — что сказать пользователю
  /// [openedSystemUninstall] — удалось ли открыть системное удаление (пока всегда false на web)
  Future<WipeResult> wipeEverything({required String pin}) async {
    final pinOk = await _security.checkPin(pin);
    if (!pinOk) {
      return WipeResult(
        success: false,
        localCleared: false,
        openedSystemUninstall: false,
        message: 'Неверный PIN',
      );
    }

    // 1) Локальные данные (SharedPreferences, outbox, PIN, профиль...)
    await _security.wipeEverything();

    // 2) Заготовка: очистка Firebase presence / dialogs этого пользователя
    await _wipeFirebaseTraces();

    // 3) Заготовка: удаление локальных файлов (когда появится path_provider)
    await _wipeLocalFiles();

    // 4) Заготовка: системное удаление приложения
    final openedUninstall = await _tryOpenSystemUninstall();

    return WipeResult(
      success: true,
      localCleared: true,
      openedSystemUninstall: openedUninstall,
      message: openedUninstall
          ? 'Данные стёрты. Подтвердите удаление приложения в системе.'
          : 'Локальные данные стёрты. Удалите приложение вручную в настройках телефона.',
    );
  }

  /// TODO: удалить presence/dialogs/сигналы пользователя в Firebase
  Future<void> _wipeFirebaseTraces() async {
    // Позже:
    // - dialogs, где members содержит username
    // - rooms/*/presence/username
    // Сейчас намеренно пусто — чтобы не затронуть чужие комнаты ошибочно.
  }

  /// TODO: временные картинки, кэш, download folder
  Future<void> _wipeLocalFiles() async {
    // Позже через path_provider + directory.delete
  }

  /// TODO: Android Intent удаления пакета
  Future<bool> _tryOpenSystemUninstall() async {
    if (kIsWeb) return false;

    // Позже:
    // final packageName = 'com.your.app';
    // final uri = Uri.parse('package:$packageName');
    // или Intent ACTION_DELETE
    return false;
  }

  /// Только кэш (аккаунт и PIN остаются) — можно вызывать с главной
  Future<void> clearCacheOnly() async {
    await _security.clearCache();
  }
}

class WipeResult {
  final bool success;
  final bool localCleared;
  final bool openedSystemUninstall;
  final String message;

  WipeResult({
    required this.success,
    required this.localCleared,
    required this.openedSystemUninstall,
    required this.message,
  });
}