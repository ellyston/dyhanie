import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/font_controller.dart';
import 'services/font_service.dart';
import 'services/icon_style_controller.dart';
import 'services/incoming_call_service.dart';
import 'services/locale_controller.dart';
import 'services/locale_service.dart';
import 'services/theme_controller.dart';
import 'services/theme_service.dart';
import 'services/webrtc_ice.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleController.instance.init();
  await FontController.instance.init();
  await IconStyleController.instance.init();
  await ThemeController.instance.init();
  await WebRtcIce.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// После возврата в приложение — пересчитать auto-тему по часу
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ThemeController.instance.refreshAuto();
    }
  }

  ThemeData _buildTheme(ThemeData base) {
    return base.copyWith(
      textTheme: FontService.applyTo(base.textTheme),
      primaryTextTheme: FontService.applyTo(base.primaryTextTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LocaleController.instance,
        FontController.instance,
        IconStyleController.instance,
        ThemeController.instance,
      ]),
      builder: (context, _) {
        final localeCode = LocaleController.instance.code;
        final fontCode = FontController.instance.code;
        final iconCode = IconStyleController.instance.code;
        final themeCode = ThemeController.instance.code;
        final isDark = ThemeService.resolvedIsDark();

        final light = _buildTheme(ThemeService.lightTheme());
        final dark = _buildTheme(ThemeService.darkTheme());

        return MaterialApp(
          // сброс дерева при смене языка / шрифта / иконок / темы
          key: ValueKey('app_${localeCode}_${fontCode}_${iconCode}_$themeCode'),
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: L.t('app_name'),
          theme: light,
          darkTheme: dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(localeCode.split('_').first),
          home: const SplashScreen(),
        );
      },
    );
  }
}