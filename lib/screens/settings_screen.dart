import 'package:flutter/material.dart';

import '../services/font_controller.dart';
import '../services/font_service.dart';
import '../services/icon_style_controller.dart';
import '../services/icon_style_service.dart';
import '../services/locale_service.dart';
import '../services/theme_controller.dart';
import '../services/theme_service.dart';
import '../services/app_version_service.dart';

import 'ask_question_screen.dart';
import 'privacy_policy_screen.dart';
import 'energy_saving_screen.dart';
import 'language_screen.dart';
import 'font_screen.dart';
import 'icon_style_screen.dart';
import 'theme_screen.dart';
import 'recovery_phrase_screen.dart';
import 'restore_phrase_screen.dart';
import 'webrtc_ice_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _versionLabel = '…';

  @override
  void initState() {
    super.initState();
    AppVersionService.instance.label().then((v) {
      if (mounted) setState(() => _versionLabel = v);
    });
  }

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
                subtitle: L.t(
                    ThemeService.catalog[ThemeService.code] ?? 'theme_dark'),
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
                    MaterialPageRoute(
                        builder: (_) => const AskQuestionScreen()),
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
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
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
                    MaterialPageRoute(
                        builder: (_) => const EnergySavingScreen()),
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
              _tile(
                icon: AppIcons.hub,
                title: L.t('webrtc_ice_title'),
                subtitle: L.t('webrtc_ice_sub'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WebrtcIceSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _section(L.t('security_section')),
              _tile(
                icon: AppIcons.vpn,
                title: L.t('recovery_phrase_menu'),
                subtitle: L.t('recovery_phrase_menu_sub'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecoveryPhraseScreen(),
                    ),
                  );
                },
              ),
              _tile(
                icon: AppIcons.restore,
                title: L.t('restore_phrase_menu'),
                subtitle: L.t('restore_phrase_menu_sub'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RestorePhraseScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _section(L.t('about_section')),
              _tile(
                icon: AppIcons.info,
                title: L.t('about'),
                subtitle: _versionLabel,
                onTap: () async {
                  final ver = await AppVersionService.instance.label();
                  if (!context.mounted) return;
                  showAboutDialog(
                    context: context,
                    applicationName: L.t('app_name'),
                    applicationVersion: ver,
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
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: FontService.style(
          color: onSurf.withValues(alpha: 0.45),
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
      title: Text(
        title,
        style: FontService.style(color: onSurf),
      ),
      subtitle: Text(
        subtitle,
        style: FontService.style(
          color: onSurf.withValues(alpha: 0.45),
        ),
      ),
      trailing: Icon(AppIcons.chevron, color: onSurf.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}