import 'package:flutter/material.dart';

import '../services/auto_lock_service.dart';
import '../services/locale_service.dart';

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
        _slider =
            _svc.timeoutMinutes <= 0 ? 0 : _svc.timeoutMinutes.toDouble();
      } else {
        _slider =
            _svc.timeoutMinutes <= 0 ? 5 : _svc.timeoutMinutes.toDouble();
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
    if (v <= 0) return L.t('never');
    if (v == 1) return L.t('minutes_1');
    if (v < 60) return L.tParams('minutes_n', {'n': '$v'});
    final h = v ~/ 60;
    final m = v % 60;
    if (m == 0) {
      return h == 1 ? L.t('hours_1') : L.tParams('hours_n', {'n': '$h'});
    }
    return L.tParams('time_h_m', {'h': '$h', 'm': '$m'});
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
        title: Text(
          L.t('auto_lock_title'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: Text(
              L.t('enabled'),
              style: const TextStyle(color: Colors.white),
            ),
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
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              L.t('when_to_lock'),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          RadioListTile<AutoLockMode>(
            value: AutoLockMode.onMinimize,
            groupValue: _svc.mode,
            activeColor: Colors.white,
            title: Text(
              L.t('lock_on_minimize'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              L.t('on_minimize_sub'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
            title: Text(
              L.t('lock_after_time'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              L.t('after_timeout_sub'),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
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
              L.tParams('timeout_label', {'label': _timeoutLabel}),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  L.t('never'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Text(
                  L.t('min_1_short'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Text(
                  L.t('hours_2_short'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            L.t('pin_unlock_hint'),
            style: const TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }
}