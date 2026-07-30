import 'package:flutter/material.dart';

import '../services/locale_service.dart';
import 'ask_question_screen.dart';
import 'privacy_policy_screen.dart';
import 'energy_saving_screen.dart';
import 'language_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          L.t('settings'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _section(L.t('support')),
          _tile(
            icon: Icons.help_outline,
            title: L.t('ask_question'),
            subtitle: L.t('ask_question_sub'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AskQuestionScreen()),
              );
            },
          ),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: L.t('privacy_policy'),
            subtitle: L.t('privacy_policy_sub'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _section(L.t('app_section')),
          _tile(
            icon: Icons.battery_saver_outlined,
            title: L.t('energy_saving'),
            subtitle: L.t('energy_saving_sub'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EnergySavingScreen()),
              );
            },
          ),
          _tile(
            icon: Icons.language,
            title: L.t('language'),
            subtitle: LocaleService.languageName(LocaleService.code),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LanguageScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _section(L.t('about_section')),
          _tile(
            icon: Icons.info_outline,
            title: L.t('about'),
            subtitle: L.t('about_sub'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Дыхание',
                applicationVersion: '0.1.0',
                applicationLegalese: 'Эфемерный приватный мессенджер',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
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