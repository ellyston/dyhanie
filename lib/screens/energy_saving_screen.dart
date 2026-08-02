import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/locale_service.dart';

class EnergySavingScreen extends StatefulWidget {
  const EnergySavingScreen({super.key});

  @override
  State<EnergySavingScreen> createState() => _EnergySavingScreenState();
}

class _EnergySavingScreenState extends State<EnergySavingScreen> {
  bool reduceAnimations = false;
  bool pauseVpnWhenBackground = true;
  bool lessPresenceUpdates = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      reduceAnimations = prefs.getBool('es_reduce_animations') ?? false;
      pauseVpnWhenBackground = prefs.getBool('es_pause_vpn_bg') ?? true;
      lessPresenceUpdates = prefs.getBool('es_less_presence') ?? false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          L.t('energy_saving'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              L.t('energy_hint'),
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            title: Text(
              L.t('less_animations'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              L.t('less_animations_sub'),
              style: const TextStyle(color: Colors.white38),
            ),
            value: reduceAnimations,
            onChanged: (v) {
              setState(() => reduceAnimations = v);
              _set('es_reduce_animations', v);
            },
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            title: Text(
              L.t('pause_vpn_bg'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              L.t('pause_vpn_bg_sub'),
              style: const TextStyle(color: Colors.white38),
            ),
            value: pauseVpnWhenBackground,
            onChanged: (v) {
              setState(() => pauseVpnWhenBackground = v);
              _set('es_pause_vpn_bg', v);
            },
          ),
          SwitchListTile(
            activeThumbColor: Colors.white,
            title: Text(
              L.t('less_presence'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              L.t('less_presence_sub'),
              style: const TextStyle(color: Colors.white38),
            ),
            value: lessPresenceUpdates,
            onChanged: (v) {
              setState(() => lessPresenceUpdates = v);
              _set('es_less_presence', v);
            },
          ),
        ],
      ),
    );
  }
}