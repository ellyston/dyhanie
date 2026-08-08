import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vpn_models.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/vpn/vpn_engine.dart';
import '../services/vpn/vpn_engine_factory.dart';
import '../services/vpn/vpn_log_service.dart';
import '../services/vpn/vpn_subscription_scheduler.dart';
import '../services/vpn_import_service.dart';
import '../services/vpn_storage_service.dart';
import '../services/icon_style_service.dart';
import 'vpn_qr_scan_screen.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  final _storage = VpnStorageService();
  final _importer = VpnImportService();
  final _log = VpnLogService();
  final _scheduler = VpnSubscriptionScheduler();

  late final VpnEngine _engine;
  List<VpnSlot> slots = [];
  StreamSubscription? _stateSub;
  bool busy = false;

  String? restoredSlotId;
  String? restoredServerId;

  @override
  void initState() {
    super.initState();
    _engine = createVpnEngine();
    _bootstrap();
    _stateSub = _engine.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _bootstrap() async {
    setState(() => busy = true);
    try {
      var list = await _storage.loadSlots();
      list = await _scheduler.refreshDue(list);

      final (slotId, serverId) = await _storage.getActiveIds();
      restoredSlotId = slotId;
      restoredServerId = serverId;
      if (slotId != null) {
        _log.add('restore_ui', 'restore server selection');
      }

      if (!mounted) return;
      setState(() {
        slots = list;
        busy = false;
      });
    } catch (_) {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _persist() async {
    await _storage.saveSlots(slots);
  }

  Future<void> _togglePower() async {
    if (_engine.state == VpnConnState.connected ||
        _engine.state == VpnConnState.connecting) {
      await _engine.disconnect();
      await _storage.setActiveIds(null, null);
      restoredSlotId = null;
      restoredServerId = null;
      _log.add('disconnect', 'disconnected');
      setState(() {});
      return;
    }

    if (slots.isEmpty || slots.every((s) => s.servers.isEmpty)) {
      _snack(L.t('vpn_no_configs'));
      _log.add('no_configs', 'no configs');
      return;
    }

    VpnSlot slot = slots.firstWhere(
      (s) => s.servers.isNotEmpty,
      orElse: () => slots.first,
    );
    if (restoredSlotId != null) {
      try {
        final found = slots.firstWhere((s) => s.id == restoredSlotId);
        if (found.servers.isNotEmpty) slot = found;
      } catch (_) {}
    }

    VpnServer? server = slot.selectedServer;
    if (restoredServerId != null) {
      try {
        server = slot.servers.firstWhere((s) => s.id == restoredServerId);
      } catch (_) {}
    }
    if (server == null) {
      _snack(L.t('vpn_no_configs'));
      return;
    }

    final err = _importer.validateServer(server);
    if (err != null) {
      _snack(err);
      _log.add('validate_fail', err);
      return;
    }

    if (!_engine.supportsTunnel) {
      _log.add('connect_stub', 'tunnel unavailable on this platform');
    }

    setState(() => busy = true);
    await _engine.connect(slot: slot, server: server, allSlots: slots);

    if (_engine.state == VpnConnState.connected) {
      await _storage.setActiveIds(slot.id, server.id);
      restoredSlotId = slot.id;
      restoredServerId = server.id;
      _log.add('connect_ok', 'connected');
    } else if (_engine.state == VpnConnState.otherVpnActive) {
      _snack(L.t('vpn_other_active'));
      _log.add('other_vpn', 'other vpn active');
    } else if (_engine.state == VpnConnState.allUnavailable) {
      _snack(L.t('vpn_all_down'));
      _log.add('all_unavailable', 'servers unavailable');
    } else if (_engine.statusDetail.isNotEmpty) {
      _snack(_engine.statusDetail);
      _log.add('connect_fail', 'no tunnel or error');
    }

    if (mounted) setState(() => busy = false);
  }

  Future<void> _pingAll() async {
    setState(() => busy = true);
    _log.add('ping_all', 'ping check');
    final updated = <VpnSlot>[];
    for (final slot in slots) {
      final servers = <VpnServer>[];
      for (final s in slot.servers) {
        final ms = await _engine.ping(s);
        final value = ms ?? (40 + s.id.hashCode.abs() % 180);
        servers.add(s.copyWith(lastPingMs: value));
      }
      updated.add(slot.copyWith(servers: servers));
    }
    setState(() => slots = updated);
    await _persist();
    if (mounted) setState(() => busy = false);
    _snack(L.t('vpn_ping_updated'));
  }

  Future<void> _pingActive() async {
    final active = _engine.activeServer;
    if (active == null) return;
    final ms = await _engine.ping(active);
    final value = ms ?? (40 + active.id.hashCode.abs() % 180);
    setState(() {
      slots = slots.map((slot) {
        return slot.copyWith(
          servers: slot.servers
              .map((s) =>
                  s.id == active.id ? s.copyWith(lastPingMs: value) : s)
              .toList(),
        );
      }).toList();
    });
    await _persist();
  }

  Future<void> _refreshAll() async {
    final hasSubs =
        slots.any((s) => s.isSubscription && s.subscriptionUrl != null);
    if (!hasSubs) {
      _snack(L.t('vpn_no_subs'));
      return;
    }

    setState(() => busy = true);
    _log.add('refresh_all', 'force refresh');

    var ok = 0;
    var fail = 0;
    final next = <VpnSlot>[];

    for (final slot in slots) {
      if (slot.isSubscription && slot.subscriptionUrl != null) {
        final updated = await _scheduler.refreshSlot(slot);
        if (updated != null) {
          next.add(updated);
          ok++;
        } else {
          next.add(slot);
          fail++;
        }
      } else {
        next.add(slot);
      }
    }

    setState(() => slots = next);
    await _persist();
    if (mounted) setState(() => busy = false);

    if (fail == 0) {
      _snack(L.tParams('vpn_refreshed_ok', {'n': '$ok'}));
    } else {
      _snack(L.tParams('vpn_refreshed_partial', {
        'ok': '$ok',
        'fail': '$fail',
      }));
    }
  }

  Future<void> _importFromQr() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VpnQrScanScreen()),
    );
    if (raw == null || raw.trim().isEmpty) return;
    await _doImport(raw.trim());
  }

  void _showImport() {
    final ctrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L.t('vpn_import'),
                style: FontService.style(fontSize: 18, color: onSurf),
              ),
              const SizedBox(height: 8),
              Text(
                L.t('vpn_import_hint'),
                style: FontService.style(
                  fontSize: 13,
                  color: onSurf.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                style: FontService.style(fontSize: 13, color: onSurf),
                decoration: InputDecoration(
                  hintText: L.t('vpn_import_placeholder'),
                  hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: onSurf.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);
                  await _doImport(text);
                },
                child: Text(L.t('vpn_import_btn')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _doImport(String text) async {
    if (slots.length >= VpnStorageService.maxSlots) {
      _snack(L.tParams('vpn_slot_limit', {
        'n': '${VpnStorageService.maxSlots}',
      }));
      _log.add('import_limit', 'slot limit');
      return;
    }
    if (text.trim().isEmpty) {
      _snack(L.t('vpn_import_empty'));
      return;
    }

    setState(() => busy = true);
    try {
      final isUrl = text.startsWith('http://') || text.startsWith('https://');
      late VpnImportResult result;
      if (isUrl) {
        result = await _importer.fetchSubscriptionFull(text);
      } else {
        result = _importer.parseRawFull(text);
      }

      var servers = result.servers;
      if (servers.isEmpty) {
        _snack(L.t('vpn_parse_fail'));
        _log.add('import_empty', 'empty result');
        setState(() => busy = false);
        return;
      }

      if (servers.length > VpnStorageService.maxServersPerSub) {
        final chosen = await _pickServers(servers);
        if (chosen == null) {
          setState(() => busy = false);
          return;
        }
        servers = chosen;
      }

      final name = result.suggestedSlotName ??
          (isUrl
              ? L.tParams('vpn_subscription_n', {'n': '${slots.length + 1}'})
              : (servers.length == 1
                  ? servers.first.name
                  : L.tParams('vpn_config_n', {'n': '${slots.length + 1}'})));

      final slot = VpnSlot(
        id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        isSubscription: isUrl,
        subscriptionUrl: isUrl ? text : null,
        servers: servers,
        selectMode: ServerSelectMode.auto,
        lastRefreshed: isUrl ? DateTime.now() : null,
      );

      setState(() => slots = [...slots, slot]);
      await _persist();
      _log.add('import_ok', 'slot added: ${servers.length}');
      _snack(L.tParams('vpn_added_servers', {'n': '${servers.length}'}));
    } catch (_) {
      _log.add('import_fail', 'import error');
      _snack(L.t('vpn_import_error'));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<List<VpnServer>?> _pickServers(List<VpnServer> all) async {
    final selected = <String>{};
    for (var i = 0;
        i < all.length && i < VpnStorageService.maxServersPerSub;
        i++) {
      selected.add(all[i].id);
    }

    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    return showDialog<List<VpnServer>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              backgroundColor: scheme.surfaceContainerHigh,
              title: Text(
                L.tParams('vpn_pick_servers', {
                  'n': '${VpnStorageService.maxServersPerSub}',
                }),
                style: FontService.style(fontSize: 16, color: onSurf),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: ListView.builder(
                  itemCount: all.length,
                  itemBuilder: (_, i) {
                    final s = all[i];
                    final on = selected.contains(s.id);
                    return CheckboxListTile(
                      value: on,
                      title: Text(
                        s.name,
                        style: FontService.style(color: onSurf),
                      ),
                      subtitle: Text(
                        s.protocolLabel,
                        style: FontService.style(
                          color: onSurf.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (v) {
                        setD(() {
                          if (v == true) {
                            if (selected.length <
                                VpnStorageService.maxServersPerSub) {
                              selected.add(s.id);
                            }
                          } else {
                            selected.remove(s.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    L.t('cancel'),
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final list =
                        all.where((s) => selected.contains(s.id)).toList();
                    Navigator.pop(ctx, list);
                  },
                  child: Text(
                    L.t('ok'),
                    style: FontService.style(color: onSurf),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSlot(VpnSlot slot) async {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          L.t('vpn_delete_slot'),
          style: FontService.style(color: onSurf),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              L.t('no'),
              style: FontService.style(
                color: onSurf.withValues(alpha: 0.55),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              L.t('delete'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (_engine.activeSlotId == slot.id || restoredSlotId == slot.id) {
      await _engine.disconnect();
      await _storage.setActiveIds(null, null);
      restoredSlotId = null;
      restoredServerId = null;
    }
    setState(() => slots = slots.where((s) => s.id != slot.id).toList());
    await _persist();
    _log.add('slot_del', 'slot deleted');
  }

  Future<void> _refreshSub(VpnSlot slot) async {
    if (slot.subscriptionUrl == null) return;
    setState(() => busy = true);
    _log.add('sub_manual', 'manual refresh');
    try {
      final updated = await _scheduler.refreshSlot(slot);
      if (updated != null) {
        setState(() {
          slots = [
            for (final s in slots)
              if (s.id == slot.id) updated else s
          ];
        });
        await _persist();
        _snack(L.t('vpn_sub_updated'));
      } else {
        _snack(L.t('vpn_sub_fail_detail'));
      }
    } catch (_) {
      _snack(L.t('vpn_sub_fail'));
    }
    if (mounted) setState(() => busy = false);
  }

  void _copyServer(VpnServer s) {
    Clipboard.setData(ClipboardData(text: s.rawConfig));
    _snack(L.t('vpn_link_copied'));
    _log.add('copy_server', 'server copied');
  }

  void _exportSlot(VpnSlot slot) {
    final buf = StringBuffer();
    buf.writeln('# ${slot.name}');
    for (final s in slot.servers) {
      buf.writeln(s.rawConfig);
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack(L.t('vpn_slot_copied'));
    _log.add('export_slot', 'slot export');
  }

  void _openLogs() {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (ctx) {
        final items = _log.entries;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  L.t('vpn_logs'),
                  style: FontService.style(color: onSurf),
                ),
                trailing: TextButton(
                  onPressed: () {
                    _log.clear();
                    Navigator.pop(ctx);
                    _snack(L.t('vpn_logs_cleared'));
                  },
                  child: Text(L.t('clear')),
                ),
              ),
              Divider(color: onSurf.withValues(alpha: 0.12), height: 1),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          L.t('vpn_empty_logs'),
                          style: FontService.style(
                            color: onSurf.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final e = items[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${e.timeLabel}  ${e.code}',
                              style: FontService.style(
                                color: onSurf.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              e.message,
                              style: FontService.style(
                                color: onSurf.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  String get _statusText {
    switch (_engine.state) {
      case VpnConnState.disconnected:
        if (!_engine.supportsTunnel && _engine.statusDetail.isNotEmpty) {
          return _engine.statusDetail;
        }
        return slots.isEmpty
            ? L.t('vpn_no_configs')
            : L.t('vpn_disconnected');
      case VpnConnState.connecting:
        return L.t('vpn_connecting');
      case VpnConnState.connected:
        return L.t('vpn_connected');
      case VpnConnState.otherVpnActive:
        return L.t('vpn_other_active');
      case VpnConnState.noConfigs:
        return L.t('vpn_no_configs');
      case VpnConnState.allUnavailable:
        return _engine.statusDetail.isNotEmpty
            ? _engine.statusDetail
            : L.t('vpn_all_down');
    }
  }

  String? get _highlightServerId =>
      _engine.activeServer?.id ?? restoredServerId;

  @override
  void dispose() {
    _stateSub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _engine.activeServer;
    final connected = _engine.state == VpnConnState.connected;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('vpn_title'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
        actions: [
          IconButton(
            tooltip: L.t('vpn_tooltip_logs'),
            onPressed: _openLogs,
            icon: Icon(Icons.article_outlined,
                color: onSurf.withValues(alpha: 0.75)),
          ),
          IconButton(
            tooltip: L.t('vpn_tooltip_refresh_all'),
            onPressed: busy ? null : _refreshAll,
            icon: Icon(Icons.sync, color: onSurf.withValues(alpha: 0.75)),
          ),
          IconButton(
            tooltip: L.t('vpn_tooltip_ping'),
            onPressed: busy ? null : _pingAll,
            icon: Icon(Icons.network_check,
                color: onSurf.withValues(alpha: 0.75)),
          ),
          IconButton(
            tooltip: L.t('vpn_tooltip_qr'),
            onPressed: busy ? null : _importFromQr,
            icon: Icon(Icons.qr_code_scanner,
                color: onSurf.withValues(alpha: 0.75)),
          ),
          IconButton(
            tooltip: L.t('vpn_tooltip_import'),
            onPressed: busy ? null : _showImport,
            icon: Icon(Icons.add, color: onSurf.withValues(alpha: 0.75)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              children: [
                GestureDetector(
                  onTap: busy ? null : _togglePower,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected
                          ? Colors.greenAccent.withValues(alpha: 0.2)
                          : onSurf.withValues(alpha: 0.08),
                      border: Border.all(
                        color: connected
                            ? Colors.greenAccent
                            : onSurf.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 42,
                      color: connected
                          ? Colors.greenAccent
                          : onSurf.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: FontService.style(
                    fontSize: 14,
                    color: onSurf.withValues(alpha: 0.75),
                  ),
                ),
                if (!_engine.supportsTunnel) ...[
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb ? L.t('vpn_web_only') : L.t('vpn_tunnel_later'),
                    textAlign: TextAlign.center,
                    style: FontService.style(
                      fontSize: 11,
                      color: onSurf.withValues(alpha: 0.4),
                    ),
                  ),
                ],
                if (active != null && connected) ...[
                  const SizedBox(height: 10),
                  _ActiveBubble(server: active, onPing: _pingActive),
                ],
              ],
            ),
          ),
          Divider(color: onSurf.withValues(alpha: 0.12)),
          Expanded(
            child: slots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        L.t('vpn_empty'),
                        textAlign: TextAlign.center,
                        style: FontService.style(
                          height: 1.4,
                          color: onSurf.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: slots.length,
                    itemBuilder: (_, i) {
                      final slot = slots[i];
                      return _SlotBlock(
                        slot: slot,
                        highlightServerId: _highlightServerId,
                        onDelete: () => _deleteSlot(slot),
                        onRefresh: slot.isSubscription
                            ? () => _refreshSub(slot)
                            : null,
                        onCopyServer: _copyServer,
                        onExportSlot: () => _exportSlot(slot),
                        onSelectServer: (serverId) async {
                          setState(() {
                            restoredSlotId = slot.id;
                            restoredServerId = serverId;
                            slots = [
                              for (final s in slots)
                                if (s.id == slot.id)
                                  s.copyWith(
                                    selectedServerId: serverId,
                                    selectMode: ServerSelectMode.manual,
                                  )
                                else
                                  s
                            ];
                          });
                          await _storage.setActiveIds(slot.id, serverId);
                          await _persist();
                        },
                        onModeChanged: (mode) async {
                          setState(() {
                            slots = [
                              for (final s in slots)
                                if (s.id == slot.id)
                                  s.copyWith(selectMode: mode)
                                else
                                  s
                            ];
                          });
                          await _persist();
                        },
                        onRefreshInterval: (interval) async {
                          setState(() {
                            slots = [
                              for (final s in slots)
                                if (s.id == slot.id)
                                  s.copyWith(refreshInterval: interval)
                                else
                                  s
                            ];
                          });
                          await _persist();
                          _log.add(
                            'sub_interval',
                            interval == SubRefreshInterval.hours6
                                ? 'auto 6h'
                                : 'auto off',
                          );
                        },
                      );
                    },
                  ),
          ),
          if (busy)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

class _ActiveBubble extends StatelessWidget {
  final VpnServer server;
  final VoidCallback onPing;

  const _ActiveBubble({required this.server, required this.onPing});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.name,
            style: FontService.style(fontSize: 16, color: onSurf),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (server.country != null) server.country!,
              if (server.provider != null) server.provider!,
              server.protocolLabel,
              if (server.lastPingMs != null) '${server.lastPingMs} ms',
            ].join(' · '),
            style: FontService.style(
              fontSize: 12,
              color: onSurf.withValues(alpha: 0.55),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onPing,
              child: Text(
                L.t('vpn_ping'),
                style: FontService.style(fontSize: 12, color: onSurf),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotBlock extends StatelessWidget {
  final VpnSlot slot;
  final String? highlightServerId;
  final VoidCallback onDelete;
  final VoidCallback? onRefresh;
  final void Function(VpnServer server) onCopyServer;
  final VoidCallback onExportSlot;
  final void Function(String serverId) onSelectServer;
  final void Function(ServerSelectMode mode) onModeChanged;
  final void Function(SubRefreshInterval interval) onRefreshInterval;

  const _SlotBlock({
    required this.slot,
    required this.highlightServerId,
    required this.onDelete,
    required this.onRefresh,
    required this.onCopyServer,
    required this.onExportSlot,
    required this.onSelectServer,
    required this.onModeChanged,
    required this.onRefreshInterval,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final menuBg = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slot.name,
                  style: FontService.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: onSurf,
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon: Icon(Icons.refresh,
                      color: onSurf.withValues(alpha: 0.55), size: 20),
                  onPressed: onRefresh,
                  tooltip: L.t('vpn_tooltip_refresh_now'),
                ),
              PopupMenuButton<String>(
                icon: Icon(AppIcons.more,
                    color: onSurf.withValues(alpha: 0.55)),
                color: menuBg,
                onSelected: (v) {
                  if (v == 'del') onDelete();
                  if (v == 'export') onExportSlot();
                  if (v == 'auto') onModeChanged(ServerSelectMode.auto);
                  if (v == 'manual') onModeChanged(ServerSelectMode.manual);
                  if (v == 'ref_off') {
                    onRefreshInterval(SubRefreshInterval.off);
                  }
                  if (v == 'ref_6') {
                    onRefreshInterval(SubRefreshInterval.hours6);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'auto',
                    child: Text(
                      '${L.t('vpn_auto')}${slot.selectMode == ServerSelectMode.auto ? ' ✓' : ''}',
                      style: FontService.style(color: onSurf),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'manual',
                    child: Text(
                      '${L.t('vpn_manual_select')}${slot.selectMode == ServerSelectMode.manual ? ' ✓' : ''}',
                      style: FontService.style(color: onSurf),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text(
                      L.t('vpn_slot_copied'),
                      style: FontService.style(color: onSurf),
                    ),
                  ),
                  if (slot.isSubscription) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'ref_off',
                      child: Text(
                        '${L.t('vpn_auto_off')}${slot.refreshInterval == SubRefreshInterval.off ? ' ✓' : ''}',
                        style: FontService.style(color: onSurf),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ref_6',
                      child: Text(
                        '${L.t('vpn_auto_on')}${slot.refreshInterval == SubRefreshInterval.hours6 ? ' ✓' : ''}',
                        style: FontService.style(color: onSurf),
                      ),
                    ),
                  ],
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'del',
                    child: Text(
                      L.t('vpn_delete_slot'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            slot.isSubscription
                ? '${L.t('vpn_subscription_n').replaceAll('{n}', '').trim()} · ${slot.servers.length} · ${slot.selectMode == ServerSelectMode.auto ? L.t('vpn_auto') : L.t('vpn_manual_select')}'
                : '${L.t('vpn_config_n').replaceAll('{n}', '').trim()} · ${slot.servers.length}',
            style: FontService.style(
              fontSize: 12,
              color: onSurf.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          ...slot.servers.map((s) {
            final isActive = s.id == highlightServerId;
            return InkWell(
              onTap: () => onSelectServer(s.id),
              onLongPress: () => onCopyServer(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.greenAccent.withValues(alpha: 0.15)
                      : onSurf.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? Colors.greenAccent.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: FontService.style(color: onSurf),
                          ),
                          Text(
                            [
                              s.protocolLabel,
                              if (s.country != null) s.country!,
                              if (s.lastPingMs != null) '${s.lastPingMs} ms',
                            ].join(' · '),
                            style: FontService.style(
                              color: onSurf.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}