import 'package:flutter/foundation.dart';

import 'font_service.dart';

class FontController extends ChangeNotifier {
  FontController._();
  static final instance = FontController._();

  String get code => FontService.code;

  Future<void> init() async {
    await FontService.init();
    notifyListeners();
  }

  Future<void> setFont(String code) async {
    await FontService.setCode(code);
    notifyListeners();
  }
}