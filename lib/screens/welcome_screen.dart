import 'package:flutter/material.dart';

import '../services/locale_service.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final bool goHomeOnContinue;

  const WelcomeScreen({
    super.key,
    this.goHomeOnContinue = false,
  });

  static const _logo = 'assets/images/welcome_logo.png';
  static const _bg = 'assets/images/welcome_bg.png';

  // тонкий «премиум» стиль без отдельного ttf
  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 40,
    fontWeight: FontWeight.w200,
    letterSpacing: 8,
    height: 1.1,
  );

  static const _subStyle = TextStyle(
    color: Colors.white60,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    letterSpacing: 2.5,
  );

  static const _sloganStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 3.2,
  );

  void _onContinue(BuildContext context) {
    if (goHomeOnContinue) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _bg,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          ),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      _logo,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 160,
                        height: 160,
                        color: Colors.white12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image, color: Colors.white38, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    L.t('app_name'),
                    textAlign: TextAlign.center,
                    style: _titleStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    L.t('ephemeral_talks'),
                    textAlign: TextAlign.center,
                    style: _subStyle,
                  ),
                  const Spacer(flex: 3),
                  // слоган без белого «пузыря»
                  TextButton(
                    onPressed: () => _onContinue(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      L.t('tagline_button'),
                      textAlign: TextAlign.center,
                      style: _sloganStyle,
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}