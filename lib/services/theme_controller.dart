import 'package:flutter/foundation.dart';

import 'theme_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  String get code => ThemeService.code;
  bool get isDark => ThemeService.resolvedIsDark();

  Future<void> init() async {
    await ThemeService.init();
    notifyListeners();
  }

  Future<void> setTheme(String code) async {
    await ThemeService.setCode(code);
    notifyListeners();
  }

  /// Вызвать при resume, чтобы auto обновился после смены часа
  void refreshAuto() {
    if (ThemeService.code == 'auto') {
      notifyListeners();
    }
  }
}