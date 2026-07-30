import '../../models/vpn_models.dart';
import 'vpn_engine.dart';

/// Web: туннеля нет. Можно сохранять конфиги и смотреть UI.
class WebVpnEngine extends BaseVpnEngine {
  @override
  bool get supportsTunnel => false;

  @override
  Future<void> connect({
    required VpnSlot slot,
    required VpnServer server,
    required List<VpnSlot> allSlots,
  }) async {
    emit(VpnConnState.connecting, detail: 'Подключение…');
    await Future.delayed(const Duration(milliseconds: 400));
    emit(
      VpnConnState.disconnected,
      detail:
          'На web VPN-туннель недоступен. Конфиги сохраняются для Android/iOS.',
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