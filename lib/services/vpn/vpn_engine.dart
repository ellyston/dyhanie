import 'dart:async';

import '../../models/vpn_models.dart';

/// Общий API VPN-движка. UI работает только через него.
abstract class VpnEngine {
  Stream<VpnConnState> get stateStream;

  VpnConnState get state;
  VpnServer? get activeServer;
  String? get activeSlotId;
  String get statusDetail;

  /// Платформа поддерживает реальный туннель (не web-заглушка).
  bool get supportsTunnel;

  Future<void> connect({
    required VpnSlot slot,
    required VpnServer server,
    required List<VpnSlot> allSlots,
  });

  Future<void> disconnect();

  Future<int?> ping(VpnServer server);

  Future<bool> reconnectWithFallback({
    required List<VpnSlot> slots,
    required String preferredSlotId,
    required String preferredServerId,
  });

  void dispose();
}

/// Базовая логика state + fallback (общая для stub/native).
abstract class BaseVpnEngine implements VpnEngine {
  final _stateCtrl = StreamController<VpnConnState>.broadcast();

  VpnConnState _state = VpnConnState.disconnected;
  VpnServer? _activeServer;
  String? _activeSlotId;
  String _statusDetail = '';

  @override
  Stream<VpnConnState> get stateStream => _stateCtrl.stream;

  @override
  VpnConnState get state => _state;

  @override
  VpnServer? get activeServer => _activeServer;

  @override
  String? get activeSlotId => _activeSlotId;

  @override
  String get statusDetail => _statusDetail;

  void emit(VpnConnState s, {String detail = '', VpnServer? server, String? slotId}) {
    _state = s;
    _statusDetail = detail;
    if (server != null) _activeServer = server;
    if (slotId != null) _activeSlotId = slotId;
    if (s == VpnConnState.disconnected) {
      _activeServer = null;
      _activeSlotId = null;
    }
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  @override
  Future<bool> reconnectWithFallback({
    required List<VpnSlot> slots,
    required String preferredSlotId,
    required String preferredServerId,
  }) async {
    VpnSlot? slot;
    try {
      slot = slots.firstWhere((s) => s.id == preferredSlotId);
    } catch (_) {
      slot = slots.isNotEmpty ? slots.first : null;
    }
    if (slot == null || slot.servers.isEmpty) {
      emit(VpnConnState.noConfigs, detail: 'Нет конфигураций');
      return false;
    }

    Future<bool> tryServer(VpnSlot sl, VpnServer sv) async {
      try {
        await connect(slot: sl, server: sv, allSlots: slots);
        return state == VpnConnState.connected;
      } catch (_) {
        return false;
      }
    }

    // 1) тот же сервер
    try {
      final same = slot.servers.firstWhere((s) => s.id == preferredServerId);
      if (await tryServer(slot, same)) return true;
    } catch (_) {}

    // 2) другие серверы слота (Reality/XHTTP раньше Hysteria2)
    final ordered = [...slot.servers]..sort((a, b) {
        int rank(VpnProtocol p) {
          switch (p) {
            case VpnProtocol.vlessReality:
            case VpnProtocol.vlessXhttp:
              return 0;
            case VpnProtocol.hysteria2:
              return 1;
            case VpnProtocol.unknown:
              return 2;
          }
        }
        return rank(a.protocol).compareTo(rank(b.protocol));
      });
    for (final s in ordered) {
      if (s.id == preferredServerId) continue;
      if (await tryServer(slot, s)) return true;
    }

    // 3) другие слоты
    for (final other in slots) {
      if (other.id == slot.id) continue;
      for (final s in other.servers) {
        if (await tryServer(other, s)) return true;
      }
    }

    emit(
      VpnConnState.allUnavailable,
      detail:
          'Не удалось подключиться. Возможно, подписка устарела или заблокирована. Попробуйте обновить её.',
    );
    return false;
  }

  @override
  void dispose() {
    _stateCtrl.close();
  }
}