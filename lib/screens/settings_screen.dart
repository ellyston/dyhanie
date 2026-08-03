import 'package:flutter/material.dart';

import '../services/font_controller.dart';
import '../services/font_service.dart';
import '../services/icon_style_controller.dart';
import '../services/icon_style_service.dart';
import '../services/locale_service.dart';
import '../services/theme_controller.dart';
import '../services/theme_service.dart';
import '../services/icon_style_service.dart' show AppIcons;
import 'ask_question_screen.dart';
import 'privacy_policy_screen.dart';
import 'energy_saving_screen.dart';
import 'language_screen.dart';
import 'font_screen.dart';
import 'icon_style_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        FontController.instance,
        IconStyleController.instance,
        ThemeController.instance,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(L.t('settings')),
          ),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              _section(L.t('appearance')),
              _tile(
                icon: AppIcons.theme,
                title: L.t('theme'),
                subtitle: L.t(ThemeService.catalog[ThemeService.code] ?? 'theme_dark'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ThemeScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _tile(
                icon: AppIcons.font,
                title: L.t('font'),
                subtitle: FontService.label(FontService.code),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FontScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              _tile(
                icon: AppIcons.iconsStyle,
                title: L.t('icon_style'),
                subtitle: IconStyleService.label(IconStyleService.code),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IconStyleScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 16),
              _section(L.t('support')),
              _tile(
                icon: AppIcons.help,
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
                icon: AppIcons.privacy,
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
                icon: AppIcons.battery,
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
                icon: AppIcons.language,
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
                icon: AppIcons.info,
                title: L.t('about'),
                subtitle: L.t('about_sub'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: L.t('app_name'),
                    applicationVersion: '0.1.0',
                    applicationLegalese: L.t('about_legalese'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: onSurf.withValues(alpha: 0.75)),
      title: Text(title, style: TextStyle(color: onSurf)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: onSurf.withValues(alpha: 0.45)),
      ),
      trailing: Icon(AppIcons.chevron, color: onSurf.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}