import 'package:shared_preferences/shared_preferences.dart';

/// ICE / TURN — часть P2P-туннеля.
/// Не связан с [blockServerMessages] (тот флаг только про relay сообщений в RTDB).
///
class WebRtcIce {
  WebRtcIce._();

  static const _kTurnUrls = 'webrtc_turn_urls';
  static const _kTurnUser = 'webrtc_turn_user';
  static const _kTurnPass = 'webrtc_turn_pass';
  static const _kStunUrls = 'webrtc_stun_urls';
  static const _kForceRelay = 'webrtc_force_relay';

  /// STUN по умолчанию, если пользователь ничего не задал.
  static const String defaultStun = 'stun:stun.l.google.com:19302';

  static String turnUrls = '';
  static String turnUser = '';
  static String turnPass = '';
  static String stunUrls = defaultStun;
  static bool forceRelayOnly = false;

  /// Читает настройки с диска в static-поля.
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    turnUrls = p.getString(_kTurnUrls) ?? '';
    turnUser = p.getString(_kTurnUser) ?? '';
    turnPass = p.getString(_kTurnPass) ?? '';
    final stun = p.getString(_kStunUrls);
    stunUrls =
        (stun == null || stun.trim().isEmpty) ? defaultStun : stun.trim();
    forceRelayOnly = p.getBool(_kForceRelay) ?? false;
  }

  /// Пишет настройки и обновляет static-поля.
  static Future<void> save({
    required String turn,
    required String user,
    required String pass,
    required String stun,
    required bool forceRelay,
  }) async {
    final p = await SharedPreferences.getInstance();
    final stunVal = stun.trim().isEmpty ? defaultStun : stun.trim();
    final turnVal = turn.trim();
    final userVal = user.trim();

    await p.setString(_kTurnUrls, turnVal);
    await p.setString(_kTurnUser, userVal);
    await p.setString(_kTurnPass, pass);
    await p.setString(_kStunUrls, stunVal);
    await p.setBool(_kForceRelay, forceRelay);

    turnUrls = turnVal;
    turnUser = userVal;
    turnPass = pass;
    stunUrls = stunVal;
    forceRelayOnly = forceRelay;
  }

  /// Конфиг для [createPeerConnection] — чат (P2P) и звонки.
  static Map<String, dynamic> get config {
    final servers = <Map<String, dynamic>>[];

    for (final u in _splitUrls(stunUrls)) {
      servers.add({'urls': u});
    }
    if (servers.isEmpty) {
      servers.add({'urls': defaultStun});
    }

    for (final u in _splitUrls(turnUrls)) {
      final entry = <String, dynamic>{'urls': u};
      if (turnUser.isNotEmpty) entry['username'] = turnUser;
      if (turnPass.isNotEmpty) entry['credential'] = turnPass;
      servers.add(entry);
    }

    final map = <String, dynamic>{
      'iceServers': servers,
    };

    if (forceRelayOnly) {
      map['iceTransportPolicy'] = 'relay';
    }

    return map;
  }

  static List<String> _splitUrls(String raw) {
    return raw
        .split(RegExp(r'[\n,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}