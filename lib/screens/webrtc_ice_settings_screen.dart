import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/webrtc_ice.dart';

class WebrtcIceSettingsScreen extends StatefulWidget {
  const WebrtcIceSettingsScreen({super.key});

  @override
  State<WebrtcIceSettingsScreen> createState() =>
      _WebrtcIceSettingsScreenState();
}

class _WebrtcIceSettingsScreenState extends State<WebrtcIceSettingsScreen> {
  final _stunCtrl = TextEditingController();
  final _turnCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _forceRelay = false;
  bool _obscure = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await WebRtcIce.load();
    if (!mounted) return;
    setState(() {
      _stunCtrl.text = WebRtcIce.stunUrls;
      _turnCtrl.text = WebRtcIce.turnUrls;
      _userCtrl.text = WebRtcIce.turnUser;
      _passCtrl.text = WebRtcIce.turnPass;
      _forceRelay = WebRtcIce.forceRelayOnly;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await WebRtcIce.save(
      turn: _turnCtrl.text,
      user: _userCtrl.text,
      pass: _passCtrl.text,
      stun: _stunCtrl.text,
      forceRelay: _forceRelay,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.t('saved'))),
    );
  }

  @override
  void dispose() {
    _stunCtrl.dispose();
    _turnCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('webrtc_ice_title'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(
              L.t('save'),
              style: FontService.style(color: onSurf),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  L.t('webrtc_ice_hint'),
                  style: FontService.style(
                    fontSize: 13,
                    color: onSurf.withValues(alpha: 0.5),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  L.t('webrtc_stun'),
                  style: FontService.style(
                    fontSize: 12,
                    color: onSurf.withValues(alpha: 0.45),
                  ),
                ),
                TextField(
                  controller: _stunCtrl,
                  style: FontService.style(color: onSurf),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'stun:stun.l.google.com:19302',
                    hintStyle: FontService.style(
                      color: onSurf.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  L.t('webrtc_turn'),
                  style: FontService.style(
                    fontSize: 12,
                    color: onSurf.withValues(alpha: 0.45),
                  ),
                ),
                TextField(
                  controller: _turnCtrl,
                  style: FontService.style(color: onSurf),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'turn:turn.example.com:3478\nturns:turn.example.com:443',
                    hintStyle: FontService.style(
                      color: onSurf.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  L.t('username'),
                  style: FontService.style(
                    fontSize: 12,
                    color: onSurf.withValues(alpha: 0.45),
                  ),
                ),
                TextField(
                  controller: _userCtrl,
                  style: FontService.style(color: onSurf),
                ),
                const SizedBox(height: 12),
                Text(
                  L.t('webrtc_turn_password'),
                  style: FontService.style(
                    fontSize: 12,
                    color: onSurf.withValues(alpha: 0.45),
                  ),
                ),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: FontService.style(color: onSurf),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: onSurf.withValues(alpha: 0.5),
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    L.t('webrtc_force_relay'),
                    style: FontService.style(color: onSurf),
                  ),
                  subtitle: Text(
                    L.t('webrtc_force_relay_sub'),
                    style: FontService.style(
                      fontSize: 12,
                      color: onSurf.withValues(alpha: 0.45),
                    ),
                  ),
                  value: _forceRelay,
                  onChanged: (v) => setState(() => _forceRelay = v),
                ),
              ],
            ),
    );
  }
}