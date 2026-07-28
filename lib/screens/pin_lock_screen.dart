import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import 'home_screen.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _ctrl = TextEditingController();
  final _security = SecurityService();
  String? _error;

  Future<void> _unlock() async {
    final pin = _ctrl.text.trim();
    final ok = await _security.checkPin(pin);
    if (!ok) {
      setState(() => _error = 'Неверный PIN');
      _ctrl.clear();
      return;
    }
    await _security.markUnlocked();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.lock_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 20),
              const Text('Введите PIN', style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 16),
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (v.length == 4) _unlock();
                },
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white24, letterSpacing: 16),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}