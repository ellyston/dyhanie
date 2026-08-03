import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_history_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/font_service.dart';
import '../services/icon_style_service.dart';
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
  static const _maxPinned = 22;
  static const _prefsPinned = 'chats_pinned';
  static const _prefsNotes = 'chats_notes';

  final _signals = DialogSignalService();
  final _outbox = OutboxService();
  final _history = ChatHistoryService();

  final Map<String, _ChatItem> items = {};
  List<String> pinnedIds = [];
  Map<String, String> notes = {};

  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
              isSaved: prev?.isSaved ?? false,
              preview: prev?.preview ?? '',
            );
          });

          items.removeWhere(
            (id, item) =>
                !keep.contains(id) &&
                !item.hasOutbox &&
                !item.isSaved &&
                !pinnedIds.contains(id),
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
                isSaved: prev.isSaved,
                preview: prev.preview,
              );
            }
          }
        });
      },
    );
  }

  Future<void> _bootstrap() async {
    await _loadMeta();
    await _loadSaved();
    await _loadLocalPending();
  }

  Future<void> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final pinRaw = prefs.getStringList(_prefsPinned) ?? [];
    final notesRaw = prefs.getString(_prefsNotes);
    if (!mounted) return;
    setState(() {
      pinnedIds = pinRaw.take(_maxPinned).toList();
      if (notesRaw != null && notesRaw.isNotEmpty) {
        try {
          notes = Map<String, String>.from(jsonDecode(notesRaw));
        } catch (_) {}
      }
    });
  }

  Future<void> _savePinned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsPinned, pinnedIds);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsNotes, jsonEncode(notes));
  }

  Future<void> _loadSaved() async {
    final saved = await _history.listSaved();
    if (!mounted) return;
    setState(() {
      for (final row in saved) {
        final id = row['roomCode']?.toString() ?? '';
        if (id.isEmpty) continue;
        final other = _otherFromDialogId(id, widget.myUsername) ?? id;
        final prev = items[id];
        items[id] = _ChatItem(
          dialogId: id,
          otherUser: other,
          incomingCount: prev?.incomingCount ?? 0,
          comeOnline: prev?.comeOnline ?? false,
          updatedAt:
              (row['updatedAt'] as int?) ?? (prev?.updatedAt ?? 0),
          hasOutbox: prev?.hasOutbox ?? false,
          isSaved: true,
          preview: row['preview']?.toString() ?? prev?.preview ?? '',
        );
      }
    });
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
          updatedAt:
              prev?.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
          hasOutbox: count > 0,
          isSaved: prev?.isSaved ?? false,
          preview: prev?.preview ?? '',
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
    list.sort((a, b) {
      final ap = pinnedIds.contains(a.dialogId);
      final bp = pinnedIds.contains(b.dialogId);
      if (ap && !bp) return -1;
      if (!ap && bp) return 1;
      if (ap && bp) {
        return pinnedIds
            .indexOf(a.dialogId)
            .compareTo(pinnedIds.indexOf(b.dialogId));
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
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
    ).then((_) async {
      await _loadSaved();
      await _loadLocalPending();
    });
  }

  Future<void> _togglePin(_ChatItem item) async {
    final id = item.dialogId;
    setState(() {
      if (pinnedIds.contains(id)) {
        pinnedIds.remove(id);
      } else {
        if (pinnedIds.length >= _maxPinned) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L.tParams('pin_limit', {'n': '$_maxPinned'}),
              ),
            ),
          );
          return;
        }
        pinnedIds.insert(0, id);
      }
    });
    await _savePinned();
  }

  void _editNote(_ChatItem item) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;
    final ctrl = TextEditingController(text: notes[item.dialogId] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          L.tParams('note_for', {'name': item.otherUser}),
          style: FontService.style(color: onSurf),
        ),
        content: TextField(
          controller: ctrl,
          style: FontService.style(color: onSurf),
          decoration: InputDecoration(
            hintText: L.t('note'),
            hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
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
            onPressed: () async {
              final t = ctrl.text.trim();
              if (t.isEmpty) {
                notes.remove(item.dialogId);
              } else {
                notes[item.dialogId] = t;
              }
              await _saveNotes();
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              L.t('save'),
              style: FontService.style(color: onSurf),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(_ChatItem item) async {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          L.t('delete_chat_title'),
          style: FontService.style(color: onSurf),
        ),
        content: Text(
          L.tParams('delete_chat_body', {'name': item.otherUser}),
          style: FontService.style(
            color: onSurf.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              L.t('cancel'),
              style: FontService.style(
                color: onSurf.withValues(alpha: 0.55),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              L.t('delete_chat'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _history.clear(item.dialogId);
    pinnedIds.remove(item.dialogId);
    notes.remove(item.dialogId);
    await _savePinned();
    await _saveNotes();
    if (!mounted) return;
    setState(() => items.remove(item.dialogId));
  }

  void _chatActions(_ChatItem item) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;
    final isPinned = pinnedIds.contains(item.dialogId);

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                AppIcons.pin,
                color: isPinned
                    ? Colors.amberAccent
                    : onSurf.withValues(alpha: 0.75),
              ),
              title: Text(
                isPinned ? L.t('unpin_chat') : L.t('pin_chat'),
                style: FontService.style(color: onSurf),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(item);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.note,
                color: onSurf.withValues(alpha: 0.75),
              ),
              title: Text(
                L.t('note'),
                style: FontService.style(color: onSurf),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _editNote(item);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.delete,
                color: Colors.redAccent,
              ),
              title: Text(
                L.t('delete'),
                style: FontService.style(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteChat(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _sorted;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('chats'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: list.isEmpty
          ? Center(
              child: Text(
                L.t('chats_empty'),
                textAlign: TextAlign.center,
                style: FontService.style(
                  color: onSurf.withValues(alpha: 0.4),
                ),
              ),
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(
                color: onSurf.withValues(alpha: 0.06),
                height: 1,
              ),
              itemBuilder: (context, i) {
                final item = list[i];
                final isPinned = pinnedIds.contains(item.dialogId);
                final note = notes[item.dialogId];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: onSurf.withValues(alpha: 0.1),
                    child: Text(
                      item.otherUser.isNotEmpty
                          ? item.otherUser[0].toUpperCase()
                          : '?',
                      style: FontService.style(color: onSurf),
                    ),
                  ),
                  title: Row(
                    children: [
                      if (isPinned) ...[
                        Icon(AppIcons.pin,
                            size: 14, color: Colors.amberAccent),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '@${item.otherUser}',
                          style: FontService.style(color: onSurf),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    (note != null && note.isNotEmpty) ? note : item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.badge > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
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
                      else if (item.hasOutbox)
                        Icon(Icons.schedule,
                            color: onSurf.withValues(alpha: 0.4), size: 18)
                      else if (item.isSaved)
                        Icon(Icons.bookmark,
                            color: onSurf.withValues(alpha: 0.35), size: 18),
                      IconButton(
                        icon: Icon(
                          AppIcons.more,
                          color: onSurf.withValues(alpha: 0.55),
                        ),
                        onPressed: () => _chatActions(item),
                      ),
                    ],
                  ),
                  onTap: () => _open(item),
                  onLongPress: () => _chatActions(item),
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
  final bool isSaved;
  final String preview;

  _ChatItem({
    required this.dialogId,
    required this.otherUser,
    required this.incomingCount,
    required this.comeOnline,
    required this.updatedAt,
    required this.hasOutbox,
    this.isSaved = false,
    this.preview = '',
  });

  int get badge => comeOnline ? 1 : incomingCount;

  String get subtitle {
    if (comeOnline) return L.t('waiting_in_chat');
    if (incomingCount > 0) {
      return L.tParams('incoming_count', {'n': '$incomingCount'});
    }
    if (hasOutbox) return L.t('outbox_waiting');
    if (preview.isNotEmpty) return preview;
    return L.t('dialog');
  }
}