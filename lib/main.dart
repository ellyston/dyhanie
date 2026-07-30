import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/locale_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDUU45D-9Grs6uhD3FaqnEupc-j_lScp40",
      authDomain: "dyhanie-19961.firebaseapp.com",
      databaseURL: "https://dyhanie-19961-default-rtdb.firebaseio.com",
      projectId: "dyhanie-19961",
      storageBucket: "dyhanie-19961.firebasestorage.app",
      messagingSenderId: "220279979423",
      appId: "1:220279979423:web:1ce259ea4fbd6f372511aa",
    ),
  );

  await LocaleController.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (context, _) {
        final code = LocaleController.instance.code;
        return MaterialApp(
          key: ValueKey('app_$code'),
          debugShowCheckedModeBanner: false,
          title: 'Дыхание',
          theme: ThemeData.dark(),
          locale: Locale(code.split('_').first), // ru / en / de
          home: const SplashScreen(),
        );
      },
    );
  }
}