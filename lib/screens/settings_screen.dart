import 'package:flutter/material.dart';

import 'vpn_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Настройки', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _tile(
            icon: Icons.timer_outlined,
            title: 'Автоблокировка',
            subtitle: 'PIN и таймаут неактивности',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скоро: экран автоблокировки')),
              );
            },
          ),
          _tile(
            icon: Icons.shield_outlined,
            title: 'VPN',
            subtitle: 'Конфиги и подключение',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VpnScreen()),
              );
            },
          ),
          _tile(
            icon: Icons.cleaning_services_outlined,
            title: 'Очистить кэш',
            subtitle: 'Временные сообщения и файлы',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Очистка кэша — с главного экрана или позже здесь'),
                ),
              );
            },
          ),
          _tile(
            icon: Icons.info_outline,
            title: 'О приложении',
            subtitle: 'Дыхание',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Дыхание',
                applicationVersion: '0.1.0',
                applicationLegalese: 'Эфемерный мессенджер',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }
}