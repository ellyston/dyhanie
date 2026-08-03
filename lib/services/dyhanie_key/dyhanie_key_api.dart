enum SessionState {
  none,
  handshaking,
  active,
  idle,
  destroyed,
}

abstract class DyhanieKeyApi {
  /// 24 слова (mock или реальные позже).
  Future<List<String>> generateRecoveryPhrase();

  /// Проверка + «восстановление» identity (stub: length == 24).
  Future<bool> restoreFromPhrase(List<String> words);

  /// UI-only safety number, 60 цифр. Не криптостойко.
  Future<String> safetyNumber({
    required String localId,
    required String remoteId,
  });

  Future<SessionState> currentSessionState(String peerId);

  Future<void> destroySession(String peerId);

  /// Заглушка handshake — всегда active через короткую задержку.
  Future<SessionState> simulateHandshake(String peerId);
}