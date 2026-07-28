import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/security_service.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';
import 'pin_lock_screen.dart';
import 'pin_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _security = SecurityService();

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final pinSet = await _security.isPinSet();
    if (!pinSet) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      return;
    }

    final needLock = await _security.needsLockScreen();
    if (needLock) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinLockScreen()),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (username == null || username.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
      );
    } else {
      await _security.markActive();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Дыхание',
          style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300),
        ),
      ),
    );
  }
}