import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contact_invite_service.dart';
import 'home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _avatar;
  String? _error;
  bool _saving = false;

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _avatar = bytes);
    }
  }

  Future<void> _save() async {
    final username = _controller.text.trim().toLowerCase();
    if (username.length < 3 || !RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(() => _error = 'Только a-z и цифры, минимум 3 символа');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      if (_avatar != null) {
        await prefs.setString('avatar', base64Encode(_avatar!));
      }

      // регистрация ника для глобального поиска
      await ContactInviteService().registerUsername(username);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка сохранения';
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
              const SizedBox(height: 40),
              const Text(
                'Профиль',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 8),
              const Text(
                'Придумайте username — по нему вас найдут',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white12,
                  backgroundImage: _avatar != null ? MemoryImage(_avatar!) : null,
                  child: _avatar == null
                      ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text('Аватар (необязательно)', style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Colors.white54),
                  errorText: _error,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Продолжить', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}