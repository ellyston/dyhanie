import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contact_invite_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/font_service.dart';
import '../services/icon_style_controller.dart';
import '../services/icon_style_service.dart';
import '../services/locale_service.dart';
import 'auto_lock_settings_screen.dart';
import 'chat_screen.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'join_room_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'vpn_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';
  Uint8List? avatarBytes;
  int contactsBadge = 0;
  int _inviteCount = 0;
  int _msgSignalCount = 0;

  final _invites = ContactInviteService();
  final _signals = DialogSignalService();
  StreamSubscription? _inviteSub;
  StreamSubscription? _msgSignalSub;

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
    _startBadgeListeners(name);
  }

  void _recalcBadge() {
    if (!mounted) return;
    setState(() => contactsBadge = _inviteCount + _msgSignalCount);
  }

  void _startBadgeListeners(String name) {
    _inviteSub?.cancel();
    _msgSignalSub?.cancel();

    if (name.isEmpty) {
      _inviteCount = 0;
      _msgSignalCount = 0;
      _recalcBadge();
      return;
    }

    _inviteSub = _invites.listenInvites(
      myUsername: name,
      onData: (list) {
        _inviteCount = list.length;
        _recalcBadge();
      },
    );

    _msgSignalSub = _signals.listenMySignals(
      myUsername: name,
      onSignals: (map) {
        int count = 0;
        map.forEach((_, data) {
          final type = data['type']?.toString() ?? '';
          if (type == 'pending_in' || type == 'come_online') count++;
        });
        _msgSignalCount = count;
        _recalcBadge();
      },
    );
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _msgSignalSub?.cancel();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(goHomeOnContinue: true),
      ),
      (_) => false,
    );
  }

  Future<void> _clearCache() async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(L.t('clear_cache_title')),
        content: Text(L.t('clear_cache_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              L.t('clear'),
              style: const TextStyle(color: Colors.redAccent),
            ),
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
      SnackBar(content: Text(L.t('cache_cleared'))),
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
    final onSurf = Theme.of(context).colorScheme.onSurface;
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
                color: onSurf.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: onSurf.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: onSurf.withValues(alpha: 0.75), size: 26),
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

  void _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(username: username),
      ),
    );
    await _loadProfile();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: IconStyleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            toolbarHeight: 96,
            leadingWidth: 56,
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: L.t('settings'),
                  icon: Icon(AppIcons.settings,
                      color: onSurf.withValues(alpha: 0.75)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                IconButton(
                  tooltip: L.t('logout'),
                  icon: Icon(AppIcons.logout,
                      color: onSurf.withValues(alpha: 0.55)),
                  onPressed: _logout,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: L.t('auto_lock'),
                icon: Icon(AppIcons.timer,
                    color: onSurf.withValues(alpha: 0.75)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AutoLockSettingsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: L.t('clear_cache'),
                icon: Icon(AppIcons.clean,
                    color: onSurf.withValues(alpha: 0.75)),
                onPressed: _clearCache,
              ),
              IconButton(
                tooltip: L.t('vpn'),
                icon: Icon(AppIcons.shield,
                    color: onSurf.withValues(alpha: 0.75)),
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
                                child: avatarBytes != null &&
                                        avatarBytes!.isNotEmpty
                                    ? Image.memory(
                                        avatarBytes!,
                                        fit: BoxFit.cover,
                                        width: 192,
                                        height: 288,
                                        gaplessPlayback: true,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color:
                                              onSurf.withValues(alpha: 0.08),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.broken_image,
                                            color: onSurf.withValues(
                                                alpha: 0.35),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color:
                                            onSurf.withValues(alpha: 0.08),
                                        alignment: Alignment.center,
                                        child: Text(
                                          username.isNotEmpty
                                              ? username[0].toUpperCase()
                                              : '?',
                                          style: FontService.style(
                                            fontSize: 64,
                                            color: onSurf,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '@$username',
                              style: FontService.style(
                                fontSize: 18,
                                color: onSurf.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              L.t('profile'),
                              style: FontService.style(
                                fontSize: 12,
                                color: onSurf.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        L.t('app_name'),
                        style: FontService.style(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                          color: onSurf,
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
                              icon: AppIcons.add,
                              tooltip: L.t('create_room'),
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
                              icon: AppIcons.login,
                              tooltip: L.t('join_by_code'),
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
                              icon: AppIcons.chat,
                              tooltip: L.t('saved_chats'),
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
                              icon: AppIcons.contacts,
                              tooltip: L.t('contacts'),
                              badge: contactsBadge,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ContactsScreen(
                                        myUsername: username),
                                  ),
                                );
                                // слушатели на home живы — бейдж обновится сам
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
      },
    );
  }
}