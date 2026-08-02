import 'package:flutter/material.dart';

import '../services/locale_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          L.t('privacy_policy'),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14),
    );
  }
}