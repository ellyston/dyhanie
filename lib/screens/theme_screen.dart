import 'package:flutter/material.dart';

import '../services/locale_service.dart';
import '../services/theme_controller.dart';
import '../services/theme_service.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = ThemeController.instance;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(L.t('theme')),
          ),
          body: ListView(
            children: [
              ...ThemeService.catalog.entries.map((e) {
                final selected = ctrl.code == e.key;
                return ListTile(
                  title: Text(L.t(e.value)),
                  subtitle: e.key == 'auto'
                      ? Text(
                          L.t('theme_auto_hint'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: selected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () async {
                    await ctrl.setTheme(e.key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}