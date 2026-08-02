import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/locale_service.dart';

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
  static const avatarKey = 'avatar';

  final _picker = ImagePicker();
  final _nameCtrl = TextEditingController();

  Uint8List? avatarBytes;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.username;
    avatarBytes = widget.avatarBytes;
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    var b64 = prefs.getString(avatarKey);
    if (b64 == null || b64.isEmpty) return;

    if (b64.contains(',')) {
      b64 = b64.split(',').last;
    }
    try {
      final bytes = base64Decode(b64);
      if (mounted) setState(() => avatarBytes = bytes);
    } catch (_) {}
  }

  Future<void> _changeAvatar() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();
    setState(() => avatarBytes = bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(avatarKey, base64Encode(bytes));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('avatar_updated'))),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('enter_username'))),
      );
      return;
    }

    setState(() => saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);

    if (avatarBytes != null) {
      await prefs.setString(avatarKey, base64Encode(avatarBytes!));
    }

    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('saved'))),
    );
    Navigator.pop(context);
  }

  Future<void> _deleteEverything() async {
    final pinOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          L.t('delete_all_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          L.t('delete_all_body'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              L.t('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              L.t('delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (pinOk != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('data_deleted'))),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          L.t('profile'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _changeAvatar,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage: avatarBytes != null
                        ? MemoryImage(avatarBytes!)
                        : null,
                    child: avatarBytes == null
                        ? const Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.white38,
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Text(
                    L.t('change_avatar'),
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            L.t('username'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      L.t('save'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _deleteEverything,
              child: Text(
                L.t('delete_all'),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            L.t('delete_all_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}