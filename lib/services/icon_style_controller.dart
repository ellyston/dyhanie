import 'package:flutter/foundation.dart';

import 'icon_style_service.dart';

class IconStyleController extends ChangeNotifier {
  IconStyleController._();
  static final instance = IconStyleController._();

  String get code => IconStyleService.code;

  Future<void> init() async {
    await IconStyleService.init();
    notifyListeners();
  }

  Future<void> setStyle(String code) async {
    await IconStyleService.setCode(code);
    notifyListeners();
  }
}