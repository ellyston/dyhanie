enum ServerRelayMode {
  /// Сообщения через сервер разрешены
  open,

  /// Сервер выкл; при падении P2P снова open
  soft,

  /// Только P2P; сам не разблокируется
  hard,
}

extension ServerRelayModeX on ServerRelayMode {
  String get prefsValue => name; // open / soft / hard

  static ServerRelayMode fromPrefs(String? raw, {bool? legacyBlock}) {
    switch (raw) {
      case 'soft':
        return ServerRelayMode.soft;
      case 'hard':
        return ServerRelayMode.hard;
      case 'open':
        return ServerRelayMode.open;
      default:
        // старый ключ block_server
        if (legacyBlock == true) return ServerRelayMode.soft;
        return ServerRelayMode.open;
    }
  }

  bool get isBlocked => this != ServerRelayMode.open;

  ServerRelayMode get next {
    switch (this) {
      case ServerRelayMode.open:
        return ServerRelayMode.soft;
      case ServerRelayMode.soft:
        return ServerRelayMode.hard;
      case ServerRelayMode.hard:
        return ServerRelayMode.open;
    }
  }
}