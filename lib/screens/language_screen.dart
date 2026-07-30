import 'package:flutter/material.dart';

import '../services/locale_controller.dart';
import '../services/locale_service.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = LocaleService.code;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          L.t('language'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          for (final code in LocaleService.supported)
            ListTile(
              title: Text(
                LocaleService.languageName(code),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: code == 'de_ch'
                  ? const Text(
                      'Schweiz',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    )
                  : null,
              trailing: current == code
                  ? const Icon(Icons.check, color: Colors.greenAccent)
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