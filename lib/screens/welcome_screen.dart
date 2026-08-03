import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';
import 'restore_phrase_screen.dart';

class WelcomeScreen extends StatelessWidget {
  /// true = выход с главной: ведёт обратно на Home, не на PIN.
  final bool goHomeOnContinue;

  const WelcomeScreen({
    super.key,
    this.goHomeOnContinue = false,
  });

  void _continue(BuildContext context) {
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
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = scheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Логотип ×2 относительно прежних 148
    const double logoSize = 296;
    const double logoRadius = 36;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg.withValues(alpha: isDark ? 0.72 : 0.82),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Логотип: ×2, скруглённые углы, мягкий градиент вокруг
                  Container(
                    width: logoSize + 28,
                    height: logoSize + 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(logoRadius + 10),
                      gradient: RadialGradient(
                        colors: [
                          onSurf.withValues(alpha: isDark ? 0.22 : 0.14),
                          onSurf.withValues(alpha: isDark ? 0.08 : 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(logoRadius),
                        boxShadow: [
                          BoxShadow(
                            color: onSurf.withValues(alpha: isDark ? 0.18 : 0.10),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(logoRadius),
                        child: Image.asset(
                          'assets/images/welcome_logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) {
                            return ColoredBox(
                              color: onSurf.withValues(alpha: 0.06),
                              child: Icon(
                                Icons.air,
                                size: 96,
                                color: onSurf.withValues(alpha: 0.85),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    L.t('app_name'),
                    textAlign: TextAlign.center,
                    style: FontService.style(
                      fontSize: 38,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 6,
                      height: 1.15,
                      color: onSurf.withValues(alpha: 0.92),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    L.t('ephemeral_talks'),
                    textAlign: TextAlign.center,
                    style: FontService.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.4,
                      height: 1.4,
                      color: onSurf.withValues(alpha: 0.42),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Слоган кликабельный — вместо кнопки «Продолжить»
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _continue(context),
                      borderRadius: BorderRadius.circular(12),
                      splashColor: onSurf.withValues(alpha: 0.08),
                      highlightColor: onSurf.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Text(
                          L.t('speak_while_breathe'),
                          textAlign: TextAlign.center,
                          style: FontService.style(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2.2,
                            height: 1.55,
                            color: onSurf.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: L.t('restore_phrase_menu'),
                      icon: Icon(
                        Icons.restore,
                        color: onSurf.withValues(alpha: 0.45),
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RestorePhraseScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}