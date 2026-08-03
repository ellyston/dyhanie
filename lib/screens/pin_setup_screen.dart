import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/security_service.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _security = SecurityService();
  String? _error;

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = L.t('pin_digits'));
      return;
    }
    if (pin != confirm) {
      setState(() => _error = L.t('pin_mismatch'));
      return;
    }

    await _security.setPin(pin);

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (!mounted) return;
    if (username == null || username.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                L.t('app_name'),
                textAlign: TextAlign.center,
                style: FontService.style(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: onSurf,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                L.t('pin_hint'),
                textAlign: TextAlign.center,
                style: FontService.style(
                  fontSize: 14,
                  color: onSurf.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: FontService.style(
                  fontSize: 28,
                  letterSpacing: 16,
                  color: onSurf,
                ),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(
                    color: onSurf.withValues(alpha: 0.25),
                    letterSpacing: 16,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: FontService.style(
                  fontSize: 28,
                  letterSpacing: 16,
                  color: onSurf,
                ),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: L.t('pin_again'),
                  hintStyle: TextStyle(
                    color: onSurf.withValues(alpha: 0.25),
                    letterSpacing: 8,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: onSurf,
                    foregroundColor: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    L.t('continue'),
                    style: FontService.style(fontSize: 17, color: bg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}