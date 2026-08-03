import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_controller.dart';
import '../services/locale_service.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = LocaleService.code;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('language'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: ListView(
        children: [
          for (final code in LocaleService.supported)
            ListTile(
              title: Text(
                LocaleService.languageName(code),
                style: FontService.style(fontSize: 16, color: onSurf),
              ),
              subtitle: code == 'de_ch'
                  ? Text(
                      'Schweiz',
                      style: FontService.style(
                        fontSize: 12,
                        color: onSurf.withValues(alpha: 0.45),
                      ),
                    )
                  : null,
              trailing: current == code
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () async {
                if (code == current) {
                  Navigator.pop(context);
                  return;
                }
                await LocaleController.instance.setLocale(code);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L.t('language_saved'))),
                );
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}