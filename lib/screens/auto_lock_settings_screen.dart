import 'package:flutter/material.dart';

import '../services/auto_lock_service.dart';

class AutoLockSettingsScreen extends StatefulWidget {
  const AutoLockSettingsScreen({super.key});

  @override
  State<AutoLockSettingsScreen> createState() => _AutoLockSettingsScreenState();
}

class _AutoLockSettingsScreenState extends State<AutoLockSettingsScreen> {
  final _svc = AutoLockService();
  bool _loading = true;

  // ползунок: 0 = никогда, 1..120 = минуты
  double _slider = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _svc.load();
    setState(() {
      if (_svc.mode == AutoLockMode.afterTimeout) {
        _slider = _svc.timeoutMinutes <= 0 ? 0 : _svc.timeoutMinutes.toDouble();
      } else {
        _slider = _svc.timeoutMinutes <= 0 ? 5 : _svc.timeoutMinutes.toDouble();
      }
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _svc.save();
    setState(() {});
  }

  String get _timeoutLabel {
    final v = _slider.round();
    if (v <= 0) return 'Никогда';
    if (v == 1) return '1 минута';
    if (v < 60) return '$v минут';
    final h = v ~/ 60;
    final m = v % 60;
    if (m == 0) return h == 1 ? '1 час' : '$h часов';
    return '$h ч $m мин';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Автоблокировка', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('Включена', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _svc.summary,
              style: const TextStyle(color: Colors.white38),
            ),
            value: _svc.enabled,
            activeColor: Colors.white,
            onChanged: (v) async {
              setState(() => _svc.enabled = v);
              await _persist();
            },
          ),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              'Когда блокировать',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          RadioListTile<AutoLockMode>(
            value: AutoLockMode.onMinimize,
            groupValue: _svc.mode,
            activeColor: Colors.white,
            title: const Text(
              'При сворачивании',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Каждый раз, когда приложение уходит в фон',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onChanged: !_svc.enabled
                ? null
                : (v) async {
                    if (v == null) return;
                    setState(() => _svc.mode = v);
                    await _persist();
                  },
          ),
          RadioListTile<AutoLockMode>(
            value: AutoLockMode.afterTimeout,
            groupValue: _svc.mode,
            activeColor: Colors.white,
            title: const Text(
              'Через время',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'PIN, если не заходили дольше выбранного',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onChanged: !_svc.enabled
                ? null
                : (v) async {
                    if (v == null) return;
                    setState(() => _svc.mode = v);
                    await _persist();
                  },
          ),
          if (_svc.enabled && _svc.mode == AutoLockMode.afterTimeout) ...[
            const SizedBox(height: 16),
            Text(
              'Таймаут: $_timeoutLabel',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(
              value: _slider.clamp(0, 120),
              min: 0,
              max: 120,
              divisions: 120,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              label: _timeoutLabel,
              onChanged: (v) {
                setState(() => _slider = v);
              },
              onChangeEnd: (v) async {
                setState(() {
                  _slider = v;
                  _svc.timeoutMinutes = v.round(); // 0 = никогда
                });
                await _persist();
              },
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Никогда', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text('1 мин', style: TextStyle(color: Colors.white38, fontSize: 11)),
                Text('2 ч', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Для разблокировки используется ваш PIN-код приложения.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }
}