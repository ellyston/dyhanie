import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatar;
  String? _error;

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _avatar = bytes);
    }
  }

  Future<void> _save() async {
    final username = _controller.text.trim().toLowerCase();

    if (username.isEmpty) {
      setState(() => _error = 'Введите имя пользователя');
      return;
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(() => _error = 'Только маленькие английские буквы и цифры');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Минимум 3 символа');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    if (_avatar != null) {
      await prefs.setString('avatar', base64Encode(_avatar!));
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
                'Создай профиль',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white12,
                  backgroundImage: _avatar != null ? MemoryImage(_avatar!) : null,
                  child: _avatar == null
                      ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Нажми, чтобы выбрать аватар',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
                ],
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: const TextStyle(color: Colors.white30),
                  errorText: _error,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
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