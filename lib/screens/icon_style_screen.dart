import 'package:flutter/material.dart';

import '../services/icon_style_controller.dart';
import '../services/icon_style_service.dart';
import '../services/locale_service.dart';

class IconStyleScreen extends StatelessWidget {
  const IconStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = IconStyleController.instance;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(L.t('icon_style')),
          ),
          body: ListView(
            children: IconStyleService.catalog.entries.map((e) {
              final selected = ctrl.code == e.key;
              // превью: временно переключаем стиль только для этой строки нельзя
              // без set — показываем имя + check
              return ListTile(
                leading: Icon(
                  e.key == 'rounded'
                      ? Icons.apps_rounded
                      : e.key == 'sharp'
                          ? Icons.apps_sharp
                          : Icons.apps_outlined,
                ),
                title: Text(e.value),
                trailing: selected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () async {
                  await ctrl.setStyle(e.key);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}