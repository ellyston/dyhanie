import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режимы: light / dark / auto (по часу суток).
/// Новый режим: ключ в [catalog] + ветка в [resolvedIsDark].
class ThemeService {
  static const prefKey = 'app_theme_mode';
  static const defaultCode = 'dark';

  /// Тёмная тема в авто: с [autoDarkFromHour] до [autoDarkUntilHour]
  static const autoDarkFromHour = 21; // 21:00
  static const autoDarkUntilHour = 7; // 07:00

  static const Map<String, String> catalog = {
    'light': 'theme_light',
    'dark': 'theme_dark',
    'auto': 'theme_auto',
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

  /// true = сейчас нужна тёмная тема
  static bool resolvedIsDark({DateTime? now}) {
    final n = now ?? DateTime.now();
    switch (_code) {
      case 'light':
        return false;
      case 'auto':
        final h = n.hour;
        // [21..23] и [0..6] — тёмная
        return h >= autoDarkFromHour || h < autoDarkUntilHour;
      case 'dark':
      default:
        return true;
    }
  }

  static ThemeMode get themeMode {
    switch (_code) {
      case 'light':
        return ThemeMode.light;
      case 'auto':
        // MaterialApp.themeMode не умеет «по часам» —
        // поэтому в main подставляем light/dark через resolvedIsDark
        return resolvedIsDark() ? ThemeMode.dark : ThemeMode.light;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F5F5),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueGrey,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueGrey,
        brightness: Brightness.dark,
      ),
    );
  }
}