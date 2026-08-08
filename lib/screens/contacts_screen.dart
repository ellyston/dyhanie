import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/contact_invite_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/dyhanie_api.dart';
import '../services/font_service.dart';
import '../services/icon_style_service.dart';
import '../services/locale_service.dart';
import '../services/outbox_service.dart';
import '../services/avatar_cache.dart';
import 'chat_screen.dart';
import 'chats_screen.dart';

class ContactsScreen extends StatefulWidget {
  final String myUsername;
  const ContactsScreen({super.key, required this.myUsername});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<String> contacts = [];
  List<String> filtered = [];
  List<String> blocked = [];
  Map<String, String> notes = {};
  Map<String, String> sounds = {};

  final _localSearch = TextEditingController();
  final _globalSearch = TextEditingController();
  final _invites = ContactInviteService();
  final _signals = DialogSignalService();
  final Map<String, Uint8List?> contactAvatars = {};

  List<Map<String, dynamic>> incomingInvites = [];
  List<Map<String, dynamic>> outgoingInvites = [];
  int incomingMessagesCount = 0;
  bool globalSending = false;

  StreamSubscription? _inviteSub;
  StreamSubscription? _outgoingSub;
  StreamSubscription? _acceptedSub;
  StreamSubscription? _msgSignalSub;

  Map<String, String> get soundPresets => {
        'default': L.t('sound_default'),
        'soft': L.t('sound_soft'),
        'alert': L.t('sound_alert'),
        'none': L.t('sound_none'),
      };

  @override
  void initState() {
    super.initState();
    _load();
    _localSearch.addListener(_filter);

    _inviteSub = _invites.listenInvites(
      myUsername: widget.myUsername,
      onData: (list) {
        if (!mounted) return;
        setState(() => incomingInvites = list);
      },
    );

    _outgoingSub = _invites.listenOutgoing(
      myUsername: widget.myUsername,
      onData: (list) {
        if (!mounted) return;
        setState(() => outgoingInvites = list);
      },
    );

    _acceptedSub = _invites.listenAccepted(
      myUsername: widget.myUsername,
      onAccepted: (by) {
        _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L.tParams('invite_accepted', {'name': by})),
          ),
        );
      },
    );

    _msgSignalSub = _signals.listenMySignals(
      myUsername: widget.myUsername,
      onSignals: (map) {
        int count = 0;
        map.forEach((_, data) {
          final type = data['type']?.toString() ?? '';
          if (type == 'pending_in' || type == 'come_online') count++;
        });
        if (!mounted) return;
        setState(() => incomingMessagesCount = count);
      },
    );
  }

  Future<void> _sendNudge(String other) async {
    final to = other.toLowerCase().trim();
    if (to.isEmpty || to == widget.myUsername.toLowerCase()) return;
    try {
      final room = OutboxService.dialogIdFor(widget.myUsername, to);
      await DyhanieApi.instance.chatNudge(to: to, room: room);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.tParams('signal_sent_to', {'name': to}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${L.t('error')}: $e')

),
      );
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('contacts') ?? [];
    final notesRaw = prefs.getString('contact_notes');
    final soundsRaw = prefs.getString('contact_sounds');
    final blockedList = await _invites.getBlocked();

    setState(() {
      contacts = raw;
      filtered = raw;
      blocked = blockedList;
      if (notesRaw != null) {
        notes = Map<String, String>.from(jsonDecode(notesRaw));
      }
      if (soundsRaw != null) {
        sounds = Map<String, String>.from(jsonDecode(soundsRaw));
      }
    });
    _filter();
    _loadAvatarsFor(List<String>.from(contacts));
  }

  Future<void> _loadAvatarsFor(List<String> names) async {
    for (final name in names) {
      final bytes = await AvatarCache.fetch(name);
      if (!mounted) return;
      if (contactAvatars[name] != bytes) {
        setState(() => contactAvatars[name] = bytes);
      }
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_notes', jsonEncode(notes));
  }

  Future<void> _saveSounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_sounds', jsonEncode(sounds));
  }

  void _filter() {
    final q = _localSearch.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? contacts
          : contacts.where((c) {
              final note = (notes[c] ?? '').toLowerCase();
              return c.contains(q) || note.contains(q);
            }).toList();
    });
  }

  Future<void> _remove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    contacts.remove(name);
    notes.remove(name);
    sounds.remove(name);
    await prefs.setStringList('contacts', contacts);
    await _saveNotes();
    await _saveSounds();
    _filter();
  }

  void _writeTo(String name) {
    final roomCode = OutboxService.dialogIdFor(widget.myUsername, name);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomCode: roomCode,
          username: widget.myUsername,
        ),
      ),
    );
  }

  Future<void> _globalSearchSubmit() async {
    final query = _globalSearch.text.trim().toLowerCase();
    if (query.isEmpty || globalSending) return;

    setState(() => globalSending = true);
    final result = await _invites.sendInvite(
      fromUsername: widget.myUsername,
      toUsername: query,
    );
    if (!mounted) return;
    setState(() => globalSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'ok'
              ? L.tParams('invite_sent_to', {'name': query})
              : result,
        ),
      ),
    );
    if (result == 'ok') _globalSearch.clear();
  }

  Future<void> _accept(String from) async {
    await _invites.acceptInvite(
      myUsername: widget.myUsername,
      fromUsername: from,
    );
    if (!mounted) return;
    setState(() {
      incomingInvites =
          incomingInvites.where((e) => e['from']?.toString() != from).toList();
    });
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.tParams('contact_added', {'name': from})),
      ),
    );
  }

  Future<void> _decline(String from) async {
    await _invites.declineInvite(
      myUsername: widget.myUsername,
      fromUsername: from,
    );
    if (!mounted) return;
    setState(() {
      incomingInvites =
          incomingInvites.where((e) => e['from']?.toString() != from).toList();
    });
  }

  Future<void> _cancelOutgoing(String to) async {
    await _invites.cancelOutgoing(
      fromUsername: widget.myUsername,
      toUsername: to,
    );
    if (!mounted) return;
    setState(() {
      outgoingInvites =
          outgoingInvites.where((e) => e['to']?.toString() != to).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.tParams('invite_cancelled', {'name': to})),
      ),
    );
  }

  Future<void> _block(String name) async {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          L.tParams('block_confirm', {'name': name}),
          style: FontService.style(color: onSurf),
        ),
        content: Text(
          L.t('block_confirm_body'),
          style: FontService.style(color: onSurf.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              L.t('cancel'),
              style: FontService.style(color: onSurf.withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              L.t('block_action'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _invites.blockUser(name);
    await _invites.declineInvite(
      myUsername: widget.myUsername,
      fromUsername: name,
    );
    await _load();
  }

  Future<void> _unblock(String name) async {
    await _invites.unblockUser(name);
    await _load();
  }

  void _editNote(String name) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;
    final controller = TextEditingController(text: notes[name] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surfaceContainerHigh,
        title: Text(
          L.tParams('note_for', {'name': name}),
          style: FontService.style(color: onSurf),
        ),
        content: TextField(
          controller: controller,
          style: FontService.style(color: onSurf),
          decoration: InputDecoration(
            hintText: L.t('note'),
            hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              notes[name] = controller.text.trim();
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

  void _pickSound(String name) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: soundPresets.entries.map((e) {
            final selected = (sounds[name] ?? 'default') == e.key;
            return ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: onSurf.withValues(alpha: 0.7),
              ),
              title: Text(e.value, style: FontService.style(color: onSurf)),
              onTap: () async {
                sounds[name] = e.key;
                await _saveSounds();
                if (mounted) setState(() {});
                if (e.key != 'none') SystemSound.play(SystemSoundType.click);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _contactActions(String name) {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.notifications_active,
                color: onSurf.withValues(alpha: 0.75),
              ),
              title: Text(
                L.t('signal_to_chat'),
                style: FontService.style(color: onSurf),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _sendNudge(name);
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
                _editNote(name);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.sound,
                color: onSurf.withValues(alpha: 0.75),
              ),
              title: Text(
                L.t('sound'),
                style: FontService.style(color: onSurf),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickSound(name);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.delete,
                color: Colors.orangeAccent,
              ),
              title: Text(
                L.t('delete'),
                style: FontService.style(color: Colors.orangeAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _remove(name);
              },
            ),
            ListTile(
              leading: Icon(
                AppIcons.block,
                color: Colors.redAccent,
              ),
              title: Text(
                L.t('block'),
                style: FontService.style(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _block(name);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localSearch.dispose();
    _globalSearch.dispose();
    _inviteSub?.cancel();
    _outgoingSub?.cancel();
    _acceptedSub?.cancel();
    _msgSignalSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          L.t('contacts_title'),
          style: FontService.style(fontSize: 18, color: onSurf),
        ),
        iconTheme: IconThemeData(color: onSurf),
      ),
      body: Column(
        children: [
          if (incomingMessagesCount > 0)
            Material(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              child: ListTile(
                leading: const Icon(
                  Icons.mark_email_unread,
                  color: Colors.lightBlueAccent,
                ),
                title: Text(
                  L.tParams('incoming_messages', {
                    'n': '$incomingMessagesCount',
                  }),
                  style: FontService.style(color: onSurf),
                ),
                subtitle: Text(
                  L.t('open_chat_to_read'),
                  style: FontService.style(
                    fontSize: 12,
                    color: onSurf.withValues(alpha: 0.55),
                  ),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: onSurf.withValues(alpha: 0.55)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatsScreen(myUsername: widget.myUsername),
                    ),
                  );
                },
              ),
            ),
          ...incomingInvites.map((inv) {
            final from = inv['from']?.toString() ?? '';
            return Material(
              color: Colors.orange.withValues(alpha: 0.15),
              child: ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1,
                  color: Colors.orangeAccent,
                ),
                title: Text(
                  L.tParams('invite_from', {'name': from}),
                  style: FontService.style(color: onSurf),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _decline(from),
                      child: Text(
                        L.t('no'),
                        style: FontService.style(
                          color: onSurf.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _accept(from),
                      child: Text(
                        L.t('yes'),
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ...outgoingInvites.map((inv) {
            final to = inv['to']?.toString() ?? '';
            return Material(
              color: onSurf.withValues(alpha: 0.04),
              child: ListTile(
                leading: Icon(Icons.hourglass_top,
                    color: onSurf.withValues(alpha: 0.55)),
                title: Text(
                  L.tParams('waiting_for', {'name': to}),
                  style: FontService.style(
                    color: onSurf.withValues(alpha: 0.75),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () => _cancelOutgoing(to),
                  child: Text(
                    L.t('cancel_invite'),
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _globalSearch,
              style: FontService.style(color: onSurf),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]')),
              ],
              decoration: InputDecoration(
                hintText: L.t('global_search'),
                hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.travel_explore,
                    color: onSurf.withValues(alpha: 0.4)),
                suffixIcon: globalSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.send,
                            color: onSurf.withValues(alpha: 0.75)),
                        onPressed: _globalSearchSubmit,
                      ),
                filled: true,
                fillColor: onSurf.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _globalSearchSubmit(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              controller: _localSearch,
              style: FontService.style(color: onSurf),
              decoration: InputDecoration(
                hintText: L.t('local_search'),
                hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                prefixIcon:
                    Icon(Icons.search, color: onSurf.withValues(alpha: 0.4)),
                filled: true,
                fillColor: onSurf.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      L.t('no_contacts'),
                      style: FontService.style(
                        color: onSurf.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final name = filtered[index];
                      final note = notes[name] ?? '';
                      return Dismissible(
                        key: Key('contact_$name'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(name),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: onSurf.withValues(alpha: 0.1),
                            backgroundImage: contactAvatars[name] != null
                                ? MemoryImage(contactAvatars[name]!)
                                : null,
                            child: contactAvatars[name] == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: FontService.style(color: onSurf),
                                  )
                                : null,
                          ),
                          title: Text(
                            '@$name',
                            style: FontService.style(color: onSurf),
                          ),
                          subtitle: note.isEmpty
                              ? null
                              : Text(
                                  note,
                                  style: FontService.style(
                                    fontSize: 12,
                                    color: onSurf.withValues(alpha: 0.4),
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: L.t('signal'),
                                icon: Icon(
                                  Icons.notifications_active,
                                  color: onSurf.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                                onPressed: () => _sendNudge(name),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: onSurf.withValues(alpha: 0.55),
                                ),
                                onPressed: () => _contactActions(name),
                              ),
                            ],
                          ),
                          onTap: () => _writeTo(name),
                          onLongPress: () => _contactActions(name),
                        ),
                      );
                    },
                  ),
          ),
          if (blocked.isNotEmpty)
            ExpansionTile(
              title: Text(
                '${L.t('blacklist')} (${blocked.length})',
                style: FontService.style(
                  color: onSurf.withValues(alpha: 0.55),
                ),
              ),
              collapsedIconColor: onSurf.withValues(alpha: 0.55),
              iconColor: onSurf.withValues(alpha: 0.75),
              children: blocked
                  .map(
                    (b) => ListTile(
                      title: Text(
                        '@$b',
                        style: FontService.style(
                          color: onSurf.withValues(alpha: 0.75),
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblock(b),
                        child: Text(
                          L.t('unblock_short'),
                          style: FontService.style(
                            color: onSurf.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}