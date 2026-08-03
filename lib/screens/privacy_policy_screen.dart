import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('privacy_policy'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _H(L.t('privacy_h1')),
          _P(L.t('privacy_p1')),
          _H(L.t('privacy_h2')),
          _P(L.t('privacy_p2')),
          _H(L.t('privacy_h3')),
          _P(L.t('privacy_p3')),
          _H(L.t('privacy_h4')),
          _P(L.t('privacy_p4')),
          _H(L.t('privacy_h5')),
          _P(L.t('privacy_p5')),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: FontService.style(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurf,
        ),
      ),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  const _P(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(
      text,
      style: FontService.style(
        fontSize: 14,
        height: 1.45,
        color: onSurf.withValues(alpha: 0.7),
      ),
    );
  }
}