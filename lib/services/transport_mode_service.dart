import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Глобально: только server или только p2p для сообщений.
enum TransportMode { server, p2p }

class TransportModeService extends ChangeNotifier {
  TransportModeService._();
  static final instance = TransportModeService._();

  static const _key = 'transport_mode';

  TransportMode _mode = TransportMode.server;
  TransportMode get mode => _mode;
  bool get isServer => _mode == TransportMode.server;
  bool get isP2p => _mode == TransportMode.p2p;

  String get label => isServer ? 'Сервер' : 'P2P';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _mode = raw == 'p2p' ? TransportMode.p2p : TransportMode.server;
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = isServer ? TransportMode.p2p : TransportMode.server;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isP2p ? 'p2p' : 'server');
    notifyListeners();
  }

  Future<void> setMode(TransportMode m) async {
    if (_mode == m) return;
    _mode = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isP2p ? 'p2p' : 'server');
    notifyListeners();
  }
}