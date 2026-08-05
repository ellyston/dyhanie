import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contact_invite_service.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import 'home_screen.dart';
import '../services/dyhanie_api.dart';

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
      setState(() => _error = L.t('username_invalid'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 1) связь с твоим VPS
      await DyhanieApi.instance.connect();

      // 2) занять username на сервере
      await DyhanieApi.instance.usernameRegister(username);

      // 3) сессия (сразу bind — дальше комнаты/signal)
      await DyhanieApi.instance.sessionBind(username);

      // 4) локально
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      if (_avatar != null) {
        await prefs.setString('avatar', base64Encode(_avatar!));
      }

      // 5) старый Firebase-register — по желанию оставь или закомментируй:
      // await ContactInviteService().registerUsername(username);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = L.t('save_error'); // позже ключ network_timeout
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        if (msg.contains('TAKEN')) {
          _error = L.t('username_taken'); // если ключа нет — временно текст ниже
        } else {
          _error = L.t('save_error');
        }
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
            children: [
              const SizedBox(height: 40),
              Text(
                L.t('profile'),
                style: FontService.style(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: onSurf,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.t('profile_subtitle'),
                textAlign: TextAlign.center,
                style: FontService.style(
                  fontSize: 14,
                  color: onSurf.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: onSurf.withValues(alpha: 0.08),
                  backgroundImage: _avatar != null ? MemoryImage(_avatar!) : null,
                  child: _avatar == null
                      ? Icon(Icons.add_a_photo, color: onSurf.withValues(alpha: 0.55), size: 32)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                L.t('avatar_optional'),
                style: FontService.style(
                  fontSize: 13,
                  color: onSurf.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                style: FontService.style(fontSize: 18, color: onSurf),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: L.t('username'),
                  labelStyle: TextStyle(color: onSurf.withValues(alpha: 0.55)),
                  errorText: _error,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurf),
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
                    backgroundColor: onSurf,
                    foregroundColor: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: bg,
                          ),
                        )
                      : Text(
                          L.t('continue'),
                          style: FontService.style(fontSize: 16, color: bg),
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