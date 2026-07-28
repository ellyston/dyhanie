import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/security_service.dart';
import 'chat_screen.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'join_room_screen.dart';
import 'profile_screen.dart';
import 'vpn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _security = SecurityService();
  String username = '';
  Uint8List? avatarBytes;
  int lockMinutes = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _loadLock();
    _security.markActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _security.markActive();
    } else if (state == AppLifecycleState.paused) {
      _security.markActive();
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? '';
    final avatarStr = prefs.getString('avatar');
    setState(() {
      username = name;
      avatarBytes = avatarStr != null ? base64Decode(avatarStr) : null;
    });
  }

  Future<void> _loadLock() async {
    final m = await _security.getLockTimeoutMinutes();
    setState(() => lockMinutes = m);
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Очистить кэш?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Удалятся временные сообщения, outbox, локальные данные чатов. Аккаунт и PIN останутся.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Очистить', style: TextStyle(color: Colors.orangeAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await _security.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Кэш очищен')),
    );
  }

  void _openSecuritySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setM) {
            final label = _security.lockLabel(lockMinutes);
            final options = SecurityService.lockOptionsMinutes;
            final index = options.indexOf(lockMinutes).clamp(0, options.length - 1);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Автоблокировка', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Через: $label', style: const TextStyle(color: Colors.white70)),
                  Slider(
                    value: index.toDouble(),
                    min: 0,
                    max: (options.length - 1).toDouble(),
                    divisions: options.length - 1,
                    activeColor: Colors.white,
                    label: label,
                    onChanged: (v) async {
                      final m = options[v.round()];
                      setM(() {});
                      setState(() => lockMinutes = m);
                      await _security.setLockTimeoutMinutes(m);
                    },
                  ),
                  const Text(
                    'От 5 минут до «Никогда»',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Очистить кэш',
            icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white70),
            onPressed: _clearCache,
          ),
          IconButton(
            tooltip: 'Автоблокировка',
            icon: const Icon(Icons.timer_outlined, color: Colors.white70),
            onPressed: _openSecuritySettings,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatsScreen(myUsername: username)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.contacts_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ContactsScreen(myUsername: username)),
              );
            },
          ),
          IconButton(
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        username: username,
                        avatarBytes: avatarBytes,
                      ),
                    ),
                  );
                  _loadProfile();
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : null,
                      child: avatarBytes == null
                          ? Text(
                              username.isNotEmpty ? username[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 28),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text('@$username', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const Text('Нажми, чтобы открыть профиль', style: TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              const Text(
                'Дыхание',
                style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300, letterSpacing: 3),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    final code = _generateRoomCode();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(roomCode: code, username: username),
                      ),
                    );
                  },
                  child: const Text('Создать комнату', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => JoinRoomScreen(username: username)),
                    );
                  },
                  child: const Text('Войти по коду', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}