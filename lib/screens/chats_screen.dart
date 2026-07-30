import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dialog_signal_service.dart';
import '../services/locale_service.dart';
import '../services/outbox_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final String myUsername;

  const ChatsScreen({super.key, required this.myUsername});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _signals = DialogSignalService();
  final _outbox = OutboxService();

  final Map<String, _ChatItem> items = {};
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadLocalPending();
    _sub = _signals.listenMySignals(
      myUsername: widget.myUsername,
      onSignals: (map) {
        setState(() {
          final keep = <String>{};

          map.forEach((dialogId, data) {
            final type = data['type']?.toString() ?? '';
            final from = data['from']?.toString() ?? '';
            final count = data['count'] is int
                ? data['count'] as int
                : int.tryParse('${data['count']}') ?? 1;
            final ts = data['ts'] is int
                ? data['ts'] as int
                : int.tryParse('${data['ts']}') ?? 0;

            final other =
                _otherFromDialogId(dialogId, widget.myUsername) ?? from;
            if (other.isEmpty) return;

            keep.add(dialogId);
            final prev = items[dialogId];
            items[dialogId] = _ChatItem(
              dialogId: dialogId,
              otherUser: other,
              incomingCount: type == 'pending_in'
                  ? count
                  : (type == 'come_online' ? 1 : (prev?.incomingCount ?? 0)),
              comeOnline: type == 'come_online',
              updatedAt: ts > 0 ? ts : (prev?.updatedAt ?? 0),
              hasOutbox: prev?.hasOutbox ?? false,
            );
          });

          items.removeWhere(
            (id, item) => !keep.contains(id) && !item.hasOutbox,
          );

          for (final id in items.keys.toList()) {
            if (!keep.contains(id)) {
              final prev = items[id]!;
              items[id] = _ChatItem(
                dialogId: prev.dialogId,
                otherUser: prev.otherUser,
                incomingCount: 0,
                comeOnline: false,
                updatedAt: prev.updatedAt,
                hasOutbox: prev.hasOutbox,
              );
            }
          }
        });
      },
    );
  }

  Future<void> _loadLocalPending() async {
    final ids = await _outbox.dialogIdsWithPending(widget.myUsername);
    for (final id in ids) {
      final other = _otherFromDialogId(id, widget.myUsername);
      if (other == null) continue;
      final count = await _outbox.countTo(widget.myUsername, other);
      if (!mounted) return;
      setState(() {
        final prev = items[id];
        items[id] = _ChatItem(
          dialogId: id,
          otherUser: other,
          incomingCount: prev?.incomingCount ?? 0,
          comeOnline: prev?.comeOnline ?? false,
          updatedAt: prev?.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
          hasOutbox: count > 0,
        );
      });
    }
  }

  String? _otherFromDialogId(String dialogId, String me) {
    final parts = dialogId.split('_');
    if (parts.length == 2) {
      return parts[0] == me ? parts[1] : parts[0];
    }
    if (dialogId.startsWith('${me}_')) {
      return dialogId.substring(me.length + 1);
    }
    if (dialogId.endsWith('_$me')) {
      return dialogId.substring(0, dialogId.length - me.length - 1);
    }
    return null;
  }

  List<_ChatItem> get _sorted {
    final list = items.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  void _open(_ChatItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomCode: item.dialogId,
          username: widget.myUsername,
        ),
      ),
    ).then((_) => _loadLocalPending());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(L.t('chats'), style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: list.isEmpty
          ? Center(
              child: Text(
                L.t('chats_empty'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38),
              ),
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              itemBuilder: (context, i) {
                final item = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Text(
                      item.otherUser.isNotEmpty
                          ? item.otherUser[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    '@${item.otherUser}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: item.badge > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.comeOnline
                                ? Colors.orangeAccent
                                : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : (item.hasOutbox
                          ? const Icon(
                              Icons.schedule,
                              color: Colors.white38,
                              size: 18,
                            )
                          : null),
                  onTap: () => _open(item),
                );
              },
            ),
    );
  }
}

class _ChatItem {
  final String dialogId;
  final String otherUser;
  final int incomingCount;
  final bool comeOnline;
  final int updatedAt;
  final bool hasOutbox;

  _ChatItem({
    required this.dialogId,
    required this.otherUser,
    required this.incomingCount,
    required this.comeOnline,
    required this.updatedAt,
    required this.hasOutbox,
  });

  int get badge => comeOnline ? 1 : incomingCount;

  String get subtitle {
    if (comeOnline) return L.t('waiting_in_chat');
    if (incomingCount > 0) {
      return L.tParams('incoming_count', {'n': '$incomingCount'});
    }
    if (hasOutbox) return L.t('outbox_waiting');
    return L.t('dialog');
  }
}