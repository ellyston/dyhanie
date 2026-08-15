import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class AppVersionService {
  AppVersionService._();
  static final instance = AppVersionService._();

  /// Пример: «1.0.1+2» или «1.0.1+2 · patch 3»
  Future<String> label() async {
    final info = await PackageInfo.fromPlatform();
    final base = '${info.version}+${info.buildNumber}';

    if (kIsWeb) return base;

    try {
      final patch = await ShorebirdUpdater().readCurrentPatch();
      final n = patch?.number;
      if (n != null) {
        return '$base · patch $n';
      }
    } catch (_) {}

    return base; // release без патча
  }
}