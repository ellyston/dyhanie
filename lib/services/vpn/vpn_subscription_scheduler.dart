import '../../models/vpn_models.dart';
import '../vpn_import_service.dart';
import '../vpn_storage_service.dart';
import 'vpn_log_service.dart';

class VpnSubscriptionScheduler {
  final _import = VpnImportService();
  final _storage = VpnStorageService();
  final _log = VpnLogService();

  static const interval6h = Duration(hours: 6);

  bool needsRefresh(VpnSlot slot) {
    if (!slot.isSubscription || slot.subscriptionUrl == null) return false;
    if (slot.refreshInterval != SubRefreshInterval.hours6) return false;
    final last = slot.lastRefreshed;
    if (last == null) return true;
    return DateTime.now().difference(last) >= interval6h;
  }

  /// Обновить одну подписку.
  Future<VpnSlot?> refreshSlot(VpnSlot slot) async {
    final url = slot.subscriptionUrl;
    if (url == null) return null;
    try {
      var servers = await _import.fetchSubscription(url);
      if (servers.length > VpnStorageService.maxServersPerSub) {
        servers = servers.take(VpnStorageService.maxServersPerSub).toList();
      }
      _log.add('sub_refresh_ok', 'Слот «${slot.name}»: ${servers.length} серв.');
      return slot.copyWith(servers: servers, lastRefreshed: DateTime.now());
    } catch (e) {
      _log.add('sub_refresh_fail', 'Слот «${slot.name}»: ошибка');
      return null;
    }
  }

  /// Все просроченные 6ч-подписки.
  Future<List<VpnSlot>> refreshDue(List<VpnSlot> slots) async {
    final out = <VpnSlot>[];
    for (final s in slots) {
      if (needsRefresh(s)) {
        final updated = await refreshSlot(s);
        out.add(updated ?? s);
      } else {
        out.add(s);
      }
    }
    await _storage.saveSlots(out);
    return out;
  }
}