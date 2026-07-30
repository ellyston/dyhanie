import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        title: const Text('Энергосбережение', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Настройки влияют на расход батареи. Часть опций применится после перезапуска экранов.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          SwitchListTile(
            activeColor: Colors.white,
            title: const Text('Меньше анимаций', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Отключить лишние переходы и эффекты',
              style: TextStyle(color: Colors.white38),
            ),
            value: reduceAnimations,
            onChanged: (v) {
              setState(() => reduceAnimations = v);
              _set('es_reduce_animations', v);
            },
          ),
          SwitchListTile(
            activeColor: Colors.white,
            title: const Text('Пауза VPN в фоне', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Не держать туннель активно при свёрнутом приложении (когда VPN будет нативным)',
              style: TextStyle(color: Colors.white38),
            ),
            value: pauseVpnWhenBackground,
            onChanged: (v) {
              setState(() => pauseVpnWhenBackground = v);
              _set('es_pause_vpn_bg', v);
            },
          ),
          SwitchListTile(
            activeColor: Colors.white,
            title: const Text('Реже обновлять online', style: TextStyle(color: Colors.white)),
            subtitle: const Text(
              'Снизить частоту presence-сигналов',
              style: TextStyle(color: Colors.white38),
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