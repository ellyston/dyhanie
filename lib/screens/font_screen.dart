import 'package:flutter/material.dart';

import '../services/font_controller.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';

class FontScreen extends StatelessWidget {
  const FontScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = FontController.instance;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(L.t('font')),
          ),
          body: ListView(
            children: FontService.catalog.entries.map((e) {
              final selected = ctrl.code == e.key;
              return ListTile(
                title: Text(
                  L.t('font_${e.key}'),
                  style: FontService.style(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ctrl.setFont(e.key);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}