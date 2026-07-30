import '../../models/vpn_models.dart';
import 'vpn_engine.dart';

/// iOS: заглушка до Network Extension.
class IOSVpnEngine extends BaseVpnEngine {
  @override
  bool get supportsTunnel => false;

  @override
  Future<void> connect({
    required VpnSlot slot,
    required VpnServer server,
    required List<VpnSlot> allSlots,
  }) async {
    emit(VpnConnState.connecting, detail: 'Подключение…');
    await Future.delayed(const Duration(milliseconds: 300));
    emit(
      VpnConnState.disconnected,
      detail:
          'iOS: VPN пока не подключён. Нужен Network Extension (Packet Tunnel).',
    );
  }

  @override
  Future<void> disconnect() async {
    emit(VpnConnState.disconnected);
  }

  @override
  Future<int?> ping(VpnServer server) async {
    await Future.delayed(
      Duration(milliseconds: 200 + server.id.hashCode.abs() % 300),
    );
    return 40 + server.id.hashCode.abs() % 180;
  }
}