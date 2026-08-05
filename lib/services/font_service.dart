import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_service.dart';


/// Чтобы добавить шрифт:
/// 1) запись в [catalog]
/// 2) case в [style] и [applyTo]
class FontService {
  static const prefKey = 'app_font';
  static const defaultCode = 'system';

  /// id → подпись в UI
  static const Map<String, String> catalog = {
    'system': 'System',
    'outfit': 'Outfit',
    'cormorant': 'Cormorant',
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

  static String label(String code) {
    final key = catalog[code];
    if (key == null) return code;
    return L.t(key);
  }

  static TextStyle style({
    double fontSize = 14,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
    switch (_code) {
      case 'outfit':
        return GoogleFonts.outfit(textStyle: base);
      case 'cormorant':
        return GoogleFonts.cormorantGaramond(textStyle: base);
      default:
        return base;
    }
  }

  static TextTheme applyTo(TextTheme base) {
    switch (_code) {
      case 'outfit':
        return GoogleFonts.outfitTextTheme(base);
      case 'cormorant':
        return GoogleFonts.cormorantGaramondTextTheme(base);
      default:
        return base;
    }
  }

}