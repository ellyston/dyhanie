import 'dyhanie_key_api.dart';

class DyhanieKeyStub implements DyhanieKeyApi {
  final Map<String, SessionState> _sessions = {};

  static const _mockWords = [
    'alpha', 'bravo', 'cedar', 'delta', 'echo', 'flint',
    'grove', 'harbor', 'ivory', 'jade', 'kite', 'lunar',
    'maple', 'nova', 'orbit', 'prism', 'quartz', 'ridge',
    'solar', 'tide', 'umbra', 'vapor', 'willow', 'zenith',
  ];

  @override
  Future<List<String>> generateRecoveryPhrase() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<String>.from(_mockWords);
  }

  @override
  Future<bool> restoreFromPhrase(List<String> words) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final cleaned = words.map((w) => w.trim().toLowerCase()).where((w) => w.isNotEmpty).toList();
    return cleaned.length == 24;
  }

  @override
  Future<String> safetyNumber({
    required String localId,
    required String remoteId,
  }) async {
    final a = localId.compareTo(remoteId) <= 0 ? localId : remoteId;
    final b = localId.compareTo(remoteId) <= 0 ? remoteId : localId;
    final base = '${a}_$b'.hashCode.abs().toRadixString(10).padLeft(12, '0');
    final buf = StringBuffer();
    while (buf.length < 60) {
      buf.write(base);
    }
    return buf.toString().substring(0, 60);
  }

  @override
  Future<SessionState> currentSessionState(String peerId) async {
    return _sessions[peerId] ?? SessionState.none;
  }

  @override
  Future<void> destroySession(String peerId) async {
    _sessions[peerId] = SessionState.destroyed;
  }

  @override
  Future<SessionState> simulateHandshake(String peerId) async {
    _sessions[peerId] = SessionState.handshaking;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _sessions[peerId] = SessionState.active;
    return SessionState.active;
  }
}

/// Единая точка доступа: потом заменить на native-реализацию.
DyhanieKeyApi dyhanieKey = DyhanieKeyStub();