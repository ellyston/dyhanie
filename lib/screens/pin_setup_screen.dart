import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import 'create_profile_screen.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      setState(() => _error = 'PIN: ровно 4 цифры');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN не совпадает');
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Дыхание',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 12),
              const Text(
                'Придумайте PIN из 4 цифр\nОн нужен для входа и полного удаления',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 16),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 16),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 16),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'ещё раз',
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 8),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
              ],
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _save,
                  child: const Text('Продолжить', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}