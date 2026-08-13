import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Принудительная проверка и установка Shorebird-патча.
class ShorebirdUpdateService {
  ShorebirdUpdateService._();
  static final instance = ShorebirdUpdateService._();

  final _updater = ShorebirdUpdater();

  /// true = патч скачан, нужен полный перезапуск приложения.
  Future<bool> checkAndDownload({bool force = true}) async {
    if (kIsWeb) return false;

    try {
      final status = await _updater.checkForUpdate();

      if (status == UpdateStatus.upToDate) {
        debugPrint('[shorebird] up to date');
        return false;
      }

      if (status == UpdateStatus.outdated || force) {
        debugPrint('[shorebird] downloading patch…');
        await _updater.update();
        debugPrint('[shorebird] patch installed — restart required');
        return true;
      }

      // unavailable / restartRequired
      debugPrint('[shorebird] status: $status');
      return status == UpdateStatus.restartRequired;
    } on UpdateException catch (e) {
      debugPrint('[shorebird] update error: ${e.message} (${e.reason})');
      return false;
    } catch (e) {
      debugPrint('[shorebird] check failed: $e');
      return false;
    }
  }

  Future<int?> currentPatchNumber() async {
    try {
      final p = await _updater.readCurrentPatch();
      return p?.number;
    } catch (_) {
      return null;
    }
  }
}