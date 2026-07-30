enum VpnProtocol { vlessReality, hysteria2, vlessXhttp, unknown }

enum ServerSelectMode { manual, auto }

enum SubRefreshInterval { off, hours6 }

enum VpnConnState {
  disconnected,
  connecting,
  connected,
  otherVpnActive,
  noConfigs,
  allUnavailable,
}

class VpnServer {
  final String id;
  final String name;
  final String? country;
  final String? provider;
  final VpnProtocol protocol;
  final String rawConfig; // JSON / share-link payload
  final int? lastPingMs;

  const VpnServer({
    required this.id,
    required this.name,
    this.country,
    this.provider,
    required this.protocol,
    required this.rawConfig,
    this.lastPingMs,
  });

  VpnServer copyWith({int? lastPingMs, String? name}) {
    return VpnServer(
      id: id,
      name: name ?? this.name,
      country: country,
      provider: provider,
      protocol: protocol,
      rawConfig: rawConfig,
      lastPingMs: lastPingMs ?? this.lastPingMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'provider': provider,
        'protocol': protocol.name,
        'rawConfig': rawConfig,
        'lastPingMs': lastPingMs,
      };

  factory VpnServer.fromJson(Map<String, dynamic> j) {
    return VpnServer(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? 'Server',
      country: j['country']?.toString(),
      provider: j['provider']?.toString(),
      protocol: VpnProtocol.values.firstWhere(
        (e) => e.name == j['protocol'],
        orElse: () => VpnProtocol.unknown,
      ),
      rawConfig: j['rawConfig']?.toString() ?? '',
      lastPingMs: j['lastPingMs'] is int ? j['lastPingMs'] as int : null,
    );
  }

  String get protocolLabel {
    switch (protocol) {
      case VpnProtocol.vlessReality:
        return 'VLESS+Reality';
      case VpnProtocol.hysteria2:
        return 'Hysteria2';
      case VpnProtocol.vlessXhttp:
        return 'VLESS+XHTTP';
      case VpnProtocol.unknown:
        return 'Unknown';
    }
  }
}

class VpnSlot {
  final String id;
  final String name;
  final bool isSubscription;
  final String? subscriptionUrl;
  final SubRefreshInterval refreshInterval;
  final DateTime? lastRefreshed;
  final List<VpnServer> servers;
  final String? selectedServerId; // для manual
  final ServerSelectMode selectMode;

  const VpnSlot({
    required this.id,
    required this.name,
    required this.isSubscription,
    this.subscriptionUrl,
    this.refreshInterval = SubRefreshInterval.off,
    this.lastRefreshed,
    this.servers = const [],
    this.selectedServerId,
    this.selectMode = ServerSelectMode.auto,
  });

  VpnSlot copyWith({
    String? name,
    List<VpnServer>? servers,
    String? selectedServerId,
    ServerSelectMode? selectMode,
    SubRefreshInterval? refreshInterval,
    DateTime? lastRefreshed,
  }) {
    return VpnSlot(
      id: id,
      name: name ?? this.name,
      isSubscription: isSubscription,
      subscriptionUrl: subscriptionUrl,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      servers: servers ?? this.servers,
      selectedServerId: selectedServerId ?? this.selectedServerId,
      selectMode: selectMode ?? this.selectMode,
    );
  }

  VpnServer? get selectedServer {
    if (servers.isEmpty) return null;
    if (selectMode == ServerSelectMode.manual && selectedServerId != null) {
      try {
        return servers.firstWhere((s) => s.id == selectedServerId);
      } catch (_) {}
    }
    // auto — с минимальным пингом или первый
    final withPing = servers.where((s) => s.lastPingMs != null).toList();
    if (withPing.isNotEmpty) {
      withPing.sort((a, b) => a.lastPingMs!.compareTo(b.lastPingMs!));
      return withPing.first;
    }
    return servers.first;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isSubscription': isSubscription,
        'subscriptionUrl': subscriptionUrl,
        'refreshInterval': refreshInterval.name,
        'lastRefreshed': lastRefreshed?.millisecondsSinceEpoch,
        'servers': servers.map((s) => s.toJson()).toList(),
        'selectedServerId': selectedServerId,
        'selectMode': selectMode.name,
      };

  factory VpnSlot.fromJson(Map<String, dynamic> j) {
    final rawServers = j['servers'];
    final list = <VpnServer>[];
    if (rawServers is List) {
      for (final e in rawServers) {
        if (e is Map) list.add(VpnServer.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return VpnSlot(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? 'Слот',
      isSubscription: j['isSubscription'] == true,
      subscriptionUrl: j['subscriptionUrl']?.toString(),
      refreshInterval: SubRefreshInterval.values.firstWhere(
        (e) => e.name == j['refreshInterval'],
        orElse: () => SubRefreshInterval.off,
      ),
      lastRefreshed: j['lastRefreshed'] is int
          ? DateTime.fromMillisecondsSinceEpoch(j['lastRefreshed'] as int)
          : null,
      servers: list,
      selectedServerId: j['selectedServerId']?.toString(),
      selectMode: ServerSelectMode.values.firstWhere(
        (e) => e.name == j['selectMode'],
        orElse: () => ServerSelectMode.auto,
      ),
    );
  }
}