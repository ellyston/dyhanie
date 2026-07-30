import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'join_room_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'auto_lock_settings_screen.dart';
import 'vpn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';
  Uint8List? avatarBytes;
  int contactsBadge = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? '';
    final b64 = prefs.getString('avatar');
    Uint8List? bytes;
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      username = name;
      avatarBytes = bytes;
    });
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Очистить кэш?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Удалятся временные сообщения и локальные черновики. Аккаунт останется.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('chat_history_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Кэш очищен')),
    );
  }

  String _generateRoomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: Colors.white70, size: 26),
            ),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openChats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatsScreen(myUsername: username),
      ),
    );
  }

  void _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(username: username),
      ),
    );
    await _loadProfile(); // обязательно
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Настройки',
          icon: const Icon(Icons.settings_outlined, color: Colors.white70),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Автоблокировка',
            icon: const Icon(Icons.timer_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => const AutoLockSettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Очистить кэш',
            icon: const Icon(
              Icons.cleaning_services_outlined,
              color: Colors.white70,
            ),
            onPressed: _clearCache,
          ),
          IconButton(
            tooltip: 'VPN',
            icon: const Icon(Icons.shield_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VpnScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _openProfile,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            width: 192,
                            height: 288,
                            child: avatarBytes != null && avatarBytes!.isNotEmpty
                                ? Image.memory(
                                   avatarBytes!,
                                   fit: BoxFit.cover,
                                   width: 192,
                                   height: 288,
                                   gaplessPlayback: true,
                                   errorBuilder: (_, __, ___) => Container(
                                     color: Colors.white12,
                                     alignment: Alignment.center,
                                     child: const Icon(Icons.broken_image, color: Colors.white38),
                                    ),
                                  )
                                : Container(
                                      color: Colors.white12,
                                      alignment: Alignment.center,
                                      child: Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 64),
                                      ),
                                    ),
                          ),
                        ),


                        const SizedBox(height: 14),
                        Text(
                          '@$username',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Профиль',
                          style: TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Дыхание',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _roundAction(
                          icon: Icons.add,
                          tooltip: 'Создать комнату',
                          onTap: () {
                            final code = _generateRoomCode();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  roomCode: code,
                                  username: username,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 28),
                        _roundAction(
                          icon: Icons.login,
                          tooltip: 'Войти по коду',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JoinRoomScreen(username: username),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _roundAction(
                          icon: Icons.chat_bubble_outline,
                          tooltip: 'Сохранённые чаты',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatsScreen(myUsername: username),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 28),
                        _roundAction(
                          icon: Icons.contacts_outlined,
                          tooltip: 'Контакты',
                          badge: contactsBadge,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ContactsScreen(myUsername: username),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}