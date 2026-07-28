import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/wipe_service.dart';
import 'pin_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final Uint8List? avatarBytes;

  const ProfileScreen({
    super.key,
    required this.username,
    this.avatarBytes,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _controller;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatar;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.username);
    _avatar = widget.avatarBytes;
  }

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
      setState(() => _error = 'Некорректный username');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    if (_avatar != null) {
      await prefs.setString('avatar', base64Encode(_avatar!));
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _wipeAll() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Удалить всё?', style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          'Будут стёрты аккаунт, PIN, контакты и локальные данные.\nЭто необратимо.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Далее', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final pinCtrl = TextEditingController();
    final pinOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Введите PIN', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(color: Colors.white, letterSpacing: 12, fontSize: 22),
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (pinOk != true || !mounted) return;

    final result = await WipeService().wipeEverything(pin: pinCtrl.text.trim());

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      (_) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        duration: const Duration(seconds: 5),
      ),
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Профиль', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
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
            const Text(
              'Сменить аватар',
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
            ),
            const SizedBox(height: 40),
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
                onPressed: _save,
                child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _wipeAll,
                child: const Text('Удалить всё полностью', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Стирает локальные данные. Удаление иконки приложения — через настройки системы.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}