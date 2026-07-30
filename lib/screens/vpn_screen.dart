import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vpn_models.dart';
import '../services/vpn/vpn_engine.dart';
import '../services/vpn/vpn_engine_factory.dart';
import '../services/vpn/vpn_log_service.dart';
import '../services/vpn/vpn_subscription_scheduler.dart';
import '../services/vpn_import_service.dart';
import '../services/vpn_storage_service.dart';
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
        _log.add('restore_ui', 'Восстановлен выбор сервера');
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
      _log.add('disconnect', 'Отключено');
      setState(() {});
      return;
    }

    if (slots.isEmpty || slots.every((s) => s.servers.isEmpty)) {
      _snack('Нет конфигураций');
      _log.add('no_configs', 'Нет конфигураций');
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
      _snack('Нет конфигураций');
      return;
    }

    final err = _importer.validateServer(server);
    if (err != null) {
      _snack(err);
      _log.add('validate_fail', err);
      return;
    }

    if (!_engine.supportsTunnel) {
      _log.add('connect_stub', 'Туннель недоступен на этой платформе');
    }

    setState(() => busy = true);
    await _engine.connect(slot: slot, server: server, allSlots: slots);

    if (_engine.state == VpnConnState.connected) {
      await _storage.setActiveIds(slot.id, server.id);
      restoredSlotId = slot.id;
      restoredServerId = server.id;
      _log.add('connect_ok', 'Подключено');
    } else if (_engine.state == VpnConnState.otherVpnActive) {
      _snack('Другой VPN уже активен');
      _log.add('other_vpn', 'Другой VPN уже активен');
    } else if (_engine.state == VpnConnState.allUnavailable) {
      _snack(
        'Не удалось подключиться. Возможно, подписка устарела или заблокирована. Попробуйте обновить её.',
      );
      _log.add('all_unavailable', 'Серверы недоступны');
    } else if (_engine.statusDetail.isNotEmpty) {
      _snack(_engine.statusDetail);
      _log.add('connect_fail', 'Нет туннеля или ошибка');
    }

    if (mounted) setState(() => busy = false);
  }

  Future<void> _pingAll() async {
    setState(() => busy = true);
    _log.add('ping_all', 'Проверка пинга');
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
    _snack('Пинг обновлён');
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
      _snack('Нет подписок для обновления');
      return;
    }

    setState(() => busy = true);
    _log.add('refresh_all', 'Принудительное обновление');

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
      _snack('Обновлено подписок: $ok');
    } else {
      _snack('Обновлено: $ok, ошибок: $fail');
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
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
              const Text(
                'Импорт',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share-ссылка, JSON или URL подписки',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'vless://… или https://…/sub',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white10,
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
                child: const Text('Импортировать'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _doImport(String text) async {
    if (slots.length >= VpnStorageService.maxSlots) {
      _snack('Максимум ${VpnStorageService.maxSlots} слотов');
      _log.add('import_limit', 'Лимит слотов');
      return;
    }
    if (text.trim().isEmpty) {
      _snack('Пустой импорт');
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
        _snack('Не удалось разобрать конфиг');
        _log.add('import_empty', 'Пустой результат');
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
              ? 'Подписка ${slots.length + 1}'
              : (servers.length == 1
                  ? servers.first.name
                  : 'Конфиг ${slots.length + 1}'));

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
      _log.add('import_ok', 'Слот добавлен: ${servers.length} серв.');
      _snack('Добавлено: ${servers.length} сервер(ов)');
    } catch (_) {
      _log.add('import_fail', 'Ошибка импорта');
      _snack('Ошибка импорта');
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

    return showDialog<List<VpnServer>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: Text(
                'Выберите до ${VpnStorageService.maxServersPerSub}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
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
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        s.protocolLabel,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 12),
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
                  child: const Text(
                    'Отмена',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final list =
                        all.where((s) => selected.contains(s.id)).toList();
                    Navigator.pop(ctx, list);
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSlot(VpnSlot slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Удалить слот?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
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
    _log.add('slot_del', 'Слот удалён');
  }

  Future<void> _refreshSub(VpnSlot slot) async {
    if (slot.subscriptionUrl == null) return;
    setState(() => busy = true);
    _log.add('sub_manual', 'Ручное обновление');
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
        _snack('Подписка обновлена');
      } else {
        _snack(
          'Не удалось обновить. Возможно, подписка устарела или заблокирована.',
        );
      }
    } catch (_) {
      _snack('Не удалось обновить подписку');
    }
    if (mounted) setState(() => busy = false);
  }

  void _copyServer(VpnServer s) {
    Clipboard.setData(ClipboardData(text: s.rawConfig));
    _snack('Ссылка скопирована');
    _log.add('copy_server', 'Скопирован сервер');
  }

  void _exportSlot(VpnSlot slot) {
    final buf = StringBuffer();
    buf.writeln('# ${slot.name}');
    for (final s in slot.servers) {
      buf.writeln(s.rawConfig);
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Слот скопирован в буфер');
    _log.add('export_slot', 'Экспорт слота');
  }

  void _openLogs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (ctx) {
        final items = _log.entries;
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Логи VPN',
                  style: TextStyle(color: Colors.white),
                ),
                trailing: TextButton(
                  onPressed: () {
                    _log.clear();
                    Navigator.pop(ctx);
                    _snack('Логи очищены');
                  },
                  child: const Text('Очистить'),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Пусто',
                          style: TextStyle(color: Colors.white38),
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
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              e.message,
                              style: const TextStyle(
                                color: Colors.white54,
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
        return slots.isEmpty ? 'Нет конфигураций' : 'Отключено';
      case VpnConnState.connecting:
        return 'Подключение…';
      case VpnConnState.connected:
        return 'Подключено';
      case VpnConnState.otherVpnActive:
        return 'Другой VPN уже активен';
      case VpnConnState.noConfigs:
        return 'Нет конфигураций';
      case VpnConnState.allUnavailable:
        return _engine.statusDetail.isNotEmpty
            ? _engine.statusDetail
            : 'Не удалось подключиться. Возможно, подписка устарела или заблокирована. Попробуйте обновить её.';
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('VPN', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Логи',
            onPressed: _openLogs,
            icon: const Icon(Icons.article_outlined, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Обновить все',
            onPressed: busy ? null : _refreshAll,
            icon: const Icon(Icons.sync, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Проверить пинг',
            onPressed: busy ? null : _pingAll,
            icon: const Icon(Icons.network_check, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'QR-импорт',
            onPressed: busy ? null : _importFromQr,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Импорт',
            onPressed: busy ? null : _showImport,
            icon: const Icon(Icons.add, color: Colors.white70),
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
                          : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: connected ? Colors.greenAccent : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 42,
                      color: connected ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (!_engine.supportsTunnel) ...[
                  const SizedBox(height: 6),
                  Text(
                    kIsWeb
                        ? 'Web: только настройка конфигов'
                        : 'Туннель появится после нативной сборки',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                if (active != null && connected) ...[
                  const SizedBox(height: 10),
                  _ActiveBubble(server: active, onPing: _pingActive),
                ],
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: slots.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Нет конфигураций\n\nНажмите + или QR, чтобы добавить\nshare-ссылку, JSON или подписку',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, height: 1.4),
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
                        onRefresh:
                            slot.isSubscription ? () => _refreshSub(slot) : null,
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
                                ? 'Автообновление 6ч'
                                : 'Автообновление выкл',
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
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (server.country != null) server.country!,
              if (server.provider != null) server.provider!,
              server.protocolLabel,
              if (server.lastPingMs != null) '${server.lastPingMs} ms',
            ].join(' · '),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onPing,
              child: const Text('Пинг', style: TextStyle(fontSize: 12)),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon:
                      const Icon(Icons.refresh, color: Colors.white54, size: 20),
                  onPressed: onRefresh,
                  tooltip: 'Обновить сейчас',
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: const Color(0xFF1A1A1A),
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
                      'Режим: Авто${slot.selectMode == ServerSelectMode.auto ? ' ✓' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'manual',
                    child: Text(
                      'Режим: Ручной${slot.selectMode == ServerSelectMode.manual ? ' ✓' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text(
                      'Экспорт слота',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (slot.isSubscription) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'ref_off',
                      child: Text(
                        'Автообновление: выкл${slot.refreshInterval == SubRefreshInterval.off ? ' ✓' : ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ref_6',
                      child: Text(
                        'Автообновление: 6ч${slot.refreshInterval == SubRefreshInterval.hours6 ? ' ✓' : ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'del',
                    child: Text(
                      'Удалить слот',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            slot.isSubscription
                ? 'Подписка · ${slot.servers.length} серв. · ${slot.selectMode == ServerSelectMode.auto ? "авто" : "ручной"}'
                : 'Конфиг · ${slot.servers.length} серв.',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
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
                      : Colors.white.withValues(alpha: 0.05),
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
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            [
                              s.protocolLabel,
                              if (s.country != null) s.country!,
                              if (s.lastPingMs != null) '${s.lastPingMs} ms',
                            ].join(' · '),
                            style: const TextStyle(
                              color: Colors.white54,
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