import 'package:flutter/foundation.dart';

import 'locale_service.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final instance = LocaleController._();

  String get code => LocaleService.code;

  Future<void> init() async {
    await LocaleService.init();
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    await LocaleService.setCode(code);
    notifyListeners();
  }
}