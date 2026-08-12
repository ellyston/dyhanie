import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_relay_mode.dart';
import '../services/chat_history_service.dart';
import '../services/chat_wipe_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/p2p_service.dart';
import '../services/dyhanie_api.dart';
import '../services/unread_chats_service.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_list.dart';
import '../services/avatar_cache.dart';
import '../services/icon_style_service.dart';
import '../services/incoming_call_service.dart';
import '../services/outbox_service.dart';
import 'call_screen.dart';
import 'emoji_picker_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final String username;

  const ChatScreen({
    super.key,
    required this.roomCode,
    required this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final _dialogSignals = DialogSignalService();
  final _wipe = ChatWipeService();
  final _history = ChatHistoryService();
  final _outbox = OutboxService();
  bool _flushingOutbox = false;

  List<Map<String, dynamic>> messages = [];
  final _timers = <String, Timer>{};
  final _remaining = <String, int>{};
  final _knownServerKeys = <String>{};

  StreamSubscription? _p2pMsgSub;
  StreamSubscription? _p2pStatusSub;
  StreamSubscription? _apiMsgSub;
  StreamSubscription? _callSignalSub;
  bool _openingCall = false;
  

  P2PService? _p2p;
  bool p2pConnected = false;
  String p2pStatusText = '';
  String connectionMode = '';

  ServerRelayMode serverRelayMode = ServerRelayMode.open;

  bool get blockServerMessages => serverRelayMode.isBlocked;

  int selectedTime = 0;
  bool wipeOnExit = false;

  double messageFontSize = 16;
  Uint8List? backgroundBytes;
  Uint8List? myAvatarBytes;
  Uint8List? otherAvatarBytes;
  String? typingUser;
  bool isSavedChat = false;
  bool saveRequestIncoming = false;
  String? saveRequestedBy;
  String? otherUser;
  bool otherOnline = false;
  bool showSearch = false;
  String searchQuery = '';
  Map<String, dynamic>? pinned;
  Map<String, dynamic>? replyTo;
  int? otherLastRead;
  bool callInProgress = false;
  String callStatusBanner = '';

  final timeOptions = [0, 5, 10, 15, 30, 60, 120, 300, 600];
  bool _looksLikeDirectDialog(String code) {
    return code.contains('_') && code.length > 6;
  }

  String? _otherFromRoomCode() {
    if (!_looksLikeDirectDialog(widget.roomCode)) return null;
    final me = widget.username;
    final code = widget.roomCode;
    final parts = code.split('_');
    if (parts.length == 2) {
      return parts[0] == me ? parts[1] : parts[0];
    }
    if (code.startsWith('${me}_')) return code.substring(me.length + 1);
    if (code.endsWith('_$me')) {
      return code.substring(0, code.length - me.length - 1);
    }
    return otherUser;
  }

  Future<void> _loadAvatars() async {
    final prefs = await SharedPreferences.getInstance();
    Uint8List? mine;
    final myRaw = prefs.getString('avatar');
    if (myRaw != null && myRaw.isNotEmpty) {
      try {
        final clean = myRaw.contains(',') ? myRaw.split(',').last : myRaw;
        mine = base64Decode(clean);
      } catch (_) {}
    }
    Uint8List? otherBytes;
    final other = otherUser ?? _otherFromRoomCode();
    if (other != null && other.isNotEmpty) {
      otherBytes = await AvatarCache.fetch(other);
    }

    if (!mounted) return;
    setState(() {
      myAvatarBytes = mine;
      otherAvatarBytes = otherBytes;
    });
  }

  String get _prefsPrefix => 'chat_cfg_${widget.roomCode}_';

  Future<void> _loadChatConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final p = _prefsPrefix;
    if (!mounted) return;
    final legacy = prefs.getBool('${p}block_server');
    final raw = prefs.getString('${p}server_relay');
    setState(() {
      wipeOnExit = prefs.getBool('${p}wipe') ?? false;
      serverRelayMode =
          ServerRelayModeX.fromPrefs(raw, legacyBlock: legacy);
      selectedTime = prefs.getInt('${p}ttl') ?? 0;
      messageFontSize = prefs.getDouble('${p}font') ?? 16.0;
    });
    _updateConnectionMode();
  }

  Future<void> _saveChatConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final p = _prefsPrefix;
    await prefs.setBool('${p}wipe', wipeOnExit);
    await prefs.setString('${p}server_relay', serverRelayMode.prefsValue);
    await prefs.setBool('${p}block_server', serverRelayMode.isBlocked);
    await prefs.setInt('${p}ttl', selectedTime);
    await prefs.setDouble('${p}font', messageFontSize);
  }

  Future<void> _clearMyIncomingSignal() async {
    if (!_looksLikeDirectDialog(widget.roomCode)) return;
    final other = _otherFromRoomCode();
    if (other == null) return;
    try {
      await _dialogSignals.clearPendingIn(from: other, to: widget.username);
    } catch (_) {}
  }

  Future<void> _loadSavedHistory() async {
    try {
      final saved = await _history.load(widget.roomCode);
      if (!mounted || saved.isEmpty) return;

      setState(() {
        final existingKeys = messages.map((m) => m['key']?.toString()).toSet();
        for (final m in saved) {
          final key = m['key']?.toString();
          if (key == null || existingKeys.contains(key)) continue;
          messages.add(m);
          _knownServerKeys.add(key);
        }
        messages.sort((a, b) {
          final ta = a['timestamp'] as int? ?? 0;
          final tb = b['timestamp'] as int? ?? 0;
          return ta.compareTo(tb);
        });
      });
      _scrollEnd();
    } catch (_) {}
  }

  Future<void> _notifyDirectIncoming() async {
    final other = _otherFromRoomCode() ?? otherUser;
    if (other == null || !_looksLikeDirectDialog(widget.roomCode)) return;
    try {
      await _dialogSignals.setPendingIn(
        from: widget.username,
        to: other,
        count: 1,
      );
    } catch (_) {}
  }

  Future<void> _bootstrapPeer() async {
    final other = _otherFromRoomCode();
    if (other == null || other.isEmpty) return;
    if (!mounted) return;
    setState(() {
      otherUser = other;
      otherOnline = true;
    });
    _updateConnectionMode();
    await _loadAvatars();

    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('contacts') ?? [];
    if (!contacts.contains(other)) {
      contacts.add(other);
      await prefs.setStringList('contacts', contacts);
    }
    await _startP2P(other);
    await _clearMyIncomingSignal();
    await _loadOutboxIntoUi(other);
  }

  Future<void> _loadOutboxIntoUi(String other) async {
    final dialogId = OutboxService.dialogIdFor(widget.username, other);
    final pending = await _outbox.pendingForDialog(
      dialogId: dialogId,
      myUsername: widget.username,
    );
    if (pending.isEmpty || !mounted) return;
    setState(() {
      final keys = messages.map((m) => m['key']?.toString()).toSet();
      for (final m in pending) {
        if (keys.contains(m.id)) continue;
        messages.add({
          'key': m.id,
          'text': m.text,
          'username': widget.username,
          'timestamp': m.timestamp,
          'ttl': m.ttl,
          'p2p': false,
          'pending': true,
          'replyText': m.replyText,
          'replyUser': m.replyUser,
          'image': m.image,
          'status': 'pending',
        });
      }
      messages.sort((a, b) =>
          (a['timestamp'] as int).compareTo(b['timestamp'] as int));
    });
  }

  @override
  void initState() {   
    IncomingCallService.instance.setChatHandlingRoom(widget.roomCode);
    super.initState();
    _loadChatConfig();
    p2pStatusText = L.t('none');
    connectionMode = L.t('no_connection');
    WidgetsBinding.instance.addObserver(this);
    _loadAvatars();
    _updateConnectionMode();
    _clearMyIncomingSignal();
    Future.delayed(const Duration(milliseconds: 300), _loadSavedHistory);
    Future.delayed(const Duration(milliseconds: 200), _bootstrapPeer);
    _listenServerMessages();
    _listenIncomingCalls();
    Future.delayed(const Duration(milliseconds: 400), _syncServerMessages);
    UnreadChatsService.instance.startListening(openRoomCode: widget.roomCode);
    UnreadChatsService.instance.clear(widget.roomCode);
    DyhanieApi.instance
      .chatNudgeAck(room: widget.roomCode)
       .catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearMyIncomingSignal();
      if (otherUser != null && _p2p == null) {
        _startP2P(otherUser!);
      }
    }
  }

  void _updateConnectionMode() {
    final mode = p2pConnected
        ? L.t('p2p_connected')
        : (otherUser != null
            ? (blockServerMessages
                ? L.t('p2p_only_wait')
                : L.t('via_server'))
            : L.t('no_connection'));
    if (mounted) setState(() => connectionMode = mode);
  }

  void _listenServerMessages() {
    _apiMsgSub?.cancel();
    _apiMsgSub = DyhanieApi.instance.events.listen((m) {
      if (m['type']?.toString() != 'msg.incoming') return;

      final p = m['payload'];
      if (p is! Map) return;

      final room = p['room']?.toString() ?? '';
      if (room != widget.roomCode) return;

      final from = (payload['from']?.toString() ?? '').toLowerCase();
      if (from.isNotEmpty && await ContactInviteService().isBlocked(from)) {
        return; // не показывать сообщение / не принимать call / p2p
      }

      final from = p['from']?.toString() ?? '';
      if (from == widget.username) return;

      final msgId = p['msg_id']?.toString() ?? '';
      if (msgId.isEmpty || _knownServerKeys.contains(msgId)) return;
      _knownServerKeys.add(msgId);

      final body = p['body']?.toString() ?? '';
      // body может быть JSON {text, image, ...} или простой текст
      String text = body;
      String? image;
      String? replyText;
      String? replyUser;
      int ttl = selectedTime;
      try {
        if (body.startsWith('{')) {
          final j = jsonDecode(body) as Map<String, dynamic>;
          text = j['text']?.toString() ?? '';
          image = j['image']?.toString();
          replyText = j['replyText']?.toString();
          replyUser = j['replyUser']?.toString();
          ttl = j['ttl'] is int ? j['ttl'] as int : selectedTime;
        }
      } catch (_) {}

      final msg = {
        'key': msgId,
        'text': text,
        'username': from,
        'timestamp': p['created_at'] is int
            ? p['created_at'] as int
            : DateTime.now().millisecondsSinceEpoch,
        'ttl': ttl,
        'p2p': false,
        'replyText': replyText,
        'replyUser': replyUser,
        'image': image,
        'status': 'delivered',
      };

      if (!mounted) return;
      setState(() => messages = [...messages, msg]);
      if (!isSavedChat && ttl > 0) _startTimer(msg);
      _scrollEnd();

      DyhanieApi.instance.msgAckRead(msgId).catchError((_) {});
    });
  }

  Future<void> _syncServerMessages() async {
    if (blockServerMessages) return;
    try {
      final list = await DyhanieApi.instance.msgSync();
      for (final p in list) {
        _ingestServerMsg(p);
      }
    } catch (_) {}
  }

  Future<void> _flushOutbox() async {
    if (_flushingOutbox) return;
    if (!p2pConnected || _p2p == null || !_p2p!.isOpen) return;

    final other = otherUser ?? _otherFromRoomCode();
    if (other == null) return;

    _flushingOutbox = true;
    try {
      final dialogId = OutboxService.dialogIdFor(widget.username, other);
      final pending = await _outbox.pendingForDialog(
        dialogId: dialogId,
        myUsername: widget.username,
      );
      if (pending.isEmpty) return;

      final sentIds = <String>[];
      for (final m in pending) {
        try {
          _p2p!.send(jsonEncode({
            'type': 'msg',
            'key': m.id,
            'text': m.text,
            'timestamp': m.timestamp,
            'ttl': m.ttl,
            'replyText': m.replyText,
            'replyUser': m.replyUser,
            'image': m.image,
          }));
          sentIds.add(m.id);
        } catch (_) {}
      }

      if (sentIds.isEmpty) return;
      await _outbox.removeByIds(sentIds);

      if (!mounted) return;
      setState(() {
        for (final msg in messages) {
          final k = msg['key']?.toString();
          if (k != null && sentIds.contains(k)) {
            msg['status'] = 'sent';
            msg['p2p'] = true;
            msg['pending'] = false;
          }
        }
      });
      if (!wipeOnExit) {
        await _history.save(widget.roomCode, messages);
      }
    } finally {
      _flushingOutbox = false;
    }
  }

  

  Future<void> _startP2P(String other) async {
    if (_p2p != null) return;

    _p2p = P2PService(
      roomCode: widget.roomCode,
      username: widget.username,
      otherUser: other,
    );

    _p2pStatusSub?.cancel();
    _p2pStatusSub = _p2p!.status.listen((s) {
      if (mounted) setState(() => p2pStatusText = s);

      // успех
      if (s == 'p2p_open') {
        if (mounted) {
          setState(() => p2pConnected = true);
          _updateConnectionMode();
          _saveChatConfig();
        }
        _flushOutbox();
        return;
      }

      // обрыв / 8 с без open → полный reconnect
      final bad = s == 'need_restart' ||
          s == 'ice_failed' ||
          s.contains('failed') ||
          s.contains('Failed') ||
          s.contains('closed') ||
          s.contains('Closed');
      if (!bad) return;

      // уже открыт — need_restart не трогаем
      if (s == 'need_restart' && p2pConnected) return;

      if (mounted) {
        setState(() {
          p2pConnected = false;
          if (serverRelayMode == ServerRelayMode.soft) {
            serverRelayMode = ServerRelayMode.open;
          }
        });
        _updateConnectionMode();
        _saveChatConfig();
      }

      _p2pMsgSub?.cancel();
      _p2pStatusSub?.cancel();
      final old = _p2p;
      _p2p = null;
      old?.dispose();

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted || otherUser == null || _p2p != null) return;
        _startP2P(otherUser!);
      });
    });

    _p2pMsgSub?.cancel();
    _p2pMsgSub = _p2p!.messages.listen((raw) {
      try {
        if (raw.startsWith('{')) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          if (data['type'] == 'clear_chat') {
            for (final t in _timers.values) {
              t.cancel();
            }
            _timers.clear();
            _remaining.clear();
            if (mounted) setState(() => messages = []);
            return;
          }
          if (data['type'] == 'delete') {
            _removeLocal(data['key']?.toString() ?? '');
            return;
          }
          if (data['type'] == 'msg') {
            _addIncomingP2P(data, other);
            return;
          }
        }
      } catch (_) {}
      _addIncomingP2P({'text': raw, 'ttl': selectedTime}, other);
    });

    try {
      await _p2p!.connect();
    } catch (e) {
      if (mounted) setState(() => p2pStatusText = '${L.t('error')}: $e');
    }
  }

  void _addIncomingP2P(Map data, String other) {
    final key = data['key']?.toString() ??
        'p2p_${DateTime.now().millisecondsSinceEpoch}';
    final msg = {
      'key': key,
      'text': data['text']?.toString() ?? '',
      'username': other,
      'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'ttl': data['ttl'] ?? selectedTime,
      'p2p': true,
      'replyText': data['replyText'],
      'replyUser': data['replyUser'],
      'image': data['image'],
      'status': 'delivered',
    };
    setState(() => messages = [...messages, msg]);
    if (!isSavedChat && (msg['ttl'] as int) > 0) _startTimer(msg);
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    _scrollEnd();
    _clearMyIncomingSignal();
  }

  void _startTimer(Map<String, dynamic> msg) {
    if (isSavedChat) return;
    final key = msg['key'] as String;
    final ttl = (msg['ttl'] as int?) ?? 0;
    if (ttl <= 0) return;

    final created = msg['timestamp'] as int;
    var remaining =
        ttl - ((DateTime.now().millisecondsSinceEpoch - created) ~/ 1000);
    if (remaining <= 0) {
      _deleteForBoth(key);
      return;
    }

    _remaining[key] = remaining;
    _timers[key]?.cancel();
    _timers[key] = Timer.periodic(const Duration(seconds: 1), (t) {
      remaining--;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining[key] = remaining);
      if (remaining <= 0) {
        t.cancel();
        _deleteForBoth(key);
      }
    });
  }

  void _removeLocal(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _remaining.remove(key);
    if (mounted) {
      setState(
          () => messages = messages.where((m) => m['key'] != key).toList());
    }
  }

  void _deleteForBoth(String key) {
    _removeLocal(key);
    if (p2pConnected && _p2p != null) {
      _p2p!.send(jsonEncode({'type': 'delete', 'key': key}));
    }
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }


  void _ingestServerMsg(Map p) {
    if (blockServerMessages) return;

    final msgId = p['msg_id']?.toString() ?? '';
    if (msgId.isEmpty) return;

    if (_knownServerKeys.contains(msgId)) {
      DyhanieApi.instance.msgAckRead(msgId).catchError((_) {});
      return;
    }

    final room = p['room']?.toString() ?? '';
    if (room != widget.roomCode) return;

    final from = p['from']?.toString() ?? '';
    if (from.isEmpty || from == widget.username) return;

    final body = p['body']?.toString() ?? '';
    String text = body;
    String? image;
    String? replyText;
    String? replyUser;
    int ttl = selectedTime;
    try {
      if (body.startsWith('{')) {
        final j = jsonDecode(body) as Map<String, dynamic>;
        text = j['text']?.toString() ?? '';
        image = j['image']?.toString();
        replyText = j['replyText']?.toString();
        replyUser = j['replyUser']?.toString();
        if (j['ttl'] is int) ttl = j['ttl'] as int;
      }
    } catch (_) {}

    final msg = <String, dynamic>{
      'key': msgId,
      'text': text,
      'username': from,
      'timestamp': p['created_at'] is int
          ? p['created_at'] as int
          : DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl,
      'p2p': false,
      'replyText': replyText,
      'replyUser': replyUser,
      'image': image,
      'status': 'delivered',
    };

    _knownServerKeys.add(msgId);

    if (!mounted) return;
    setState(() => messages = [...messages, msg]);
    if (!isSavedChat && ttl > 0) _startTimer(msg);
    _scrollEnd();

    DyhanieApi.instance.msgAckRead(msgId).catchError((_) {});
    UnreadChatsService.instance.clear(widget.roomCode);
  }


  Future<void> _send({String? imageB64}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && imageB64 == null) return;

    final other = otherUser ?? _otherFromRoomCode();
    final canP2P =
        p2pConnected && _p2p != null && _p2p!.isOpen;

    // open — сервер всегда можно; soft/hard — сервер выкл
    final canServer = serverRelayMode == ServerRelayMode.open;

    // outbox только hard (и по желанию soft). НЕ open.
    final useOutbox = !canP2P &&
        (serverRelayMode == ServerRelayMode.hard ||
            serverRelayMode == ServerRelayMode.soft);

    if (!canP2P && !canServer && !useOutbox) {
      return;
    }
    if ((canServer || useOutbox) && other == null) {
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    late String key;
    late String status;

    if (canP2P) {
      key = 'p2p_$ts';
      status = 'sent';
    } else if (useOutbox) {
      final ob = await _outbox.add(
        from: widget.username,
        to: other!,
        text: text,
        ttl: selectedTime,
        image: imageB64,
        replyText: replyTo?['text']?.toString(),
        replyUser: replyTo?['username']?.toString(),
      );
      key = ob.id;
      status = 'pending';
    } else {
      // open + нет P2P → сервер
      key = 'srv_$ts';
      status = 'sent';
    }

    final msg = {
      'key': key,
      'text': text,
      'username': widget.username,
      'timestamp': ts,
      'ttl': selectedTime,
      'p2p': canP2P,
      'pending': status == 'pending',
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
      'image': imageB64,
      'status': status,
    };

    setState(() {
      messages = [...messages, msg];
      replyTo = null;
    });
    if (!isSavedChat && selectedTime > 0) _startTimer(msg);
    _scrollEnd();

    if (canP2P) {
      _p2p!.send(jsonEncode({
        'type': 'msg',
        'key': key,
        'text': text,
        'timestamp': ts,
        'ttl': selectedTime,
        'replyText': msg['replyText'],
        'replyUser': msg['replyUser'],
        'image': imageB64,
      }));
    } else if (canServer && !useOutbox) {
      final body = jsonEncode({
        'text': text,
        'ttl': selectedTime,
        'replyText': msg['replyText'],
        'replyUser': msg['replyUser'],
        'image': imageB64,
      });
      try {
        await DyhanieApi.instance.msgSend(
          room: widget.roomCode,
          to: other!,
          msgId: key,
          body: body,
          contentType: imageB64 != null ? 'image' : 'text',
        );
        _knownServerKeys.add(key);
      } catch (e) {
        if (mounted) {
          setState(() {
            final i = messages.indexWhere((m) => m['key'] == key);
            if (i >= 0) messages[i]['status'] = 'error';
          });
        }
      }
    }

    await _notifyDirectIncoming();
    _controller.clear();
    HapticFeedback.lightImpact();
    if (!wipeOnExit) {
      await _history.save(widget.roomCode, messages);
    }
  }
  
  Future<void> _attach() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 70,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (bytes.length > 600000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('file_too_big'))),
      );
      return;
    }
    await _send(imageB64: base64Encode(bytes));
  }

  Future<void> _openEmoji() async {
    final emoji = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const EmojiPickerScreen()),
    );
    if (emoji == null || !mounted) return;
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _pinMessage(Map<String, dynamic> msg) {
    setState(() {
      pinned = {
        'text': msg['text'],
        'username': msg['username'],
        'key': msg['key'],
      };
    });
  }

  void _messageActions(Map<String, dynamic> msg) {
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
              leading: Icon(AppIcons.reply, color: onSurf.withValues(alpha: 0.7)),
              title: Text(L.t('reply'), style: FontService.style(color: onSurf)),
              onTap: () {
                setState(() => replyTo = msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.pin, color: onSurf.withValues(alpha: 0.7)),
              title: Text(L.t('pin_message'), style: FontService.style(color: onSurf)),
              onTap: () {
                _pinMessage(msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.copy, color: onSurf.withValues(alpha: 0.7)),
              title: Text(L.t('copy'), style: FontService.style(color: onSurf)),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: msg['text']?.toString() ?? ''),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L.t('copied'))),
                );
              },
            ),
            if (msg['username'] == widget.username)
              ListTile(
                leading: Icon(AppIcons.delete, color: Colors.redAccent),
                title: Text(
                  L.t('delete_for_all'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  _deleteForBoth(msg['key'] as String);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exitRoom() async {
    await _wipe.leavePresence(
      roomCode: widget.roomCode,
      username: widget.username,
    );

    if (wipeOnExit) {
      await _history.clear(widget.roomCode);
      await _wipe.wipeEverywhere(
        roomCode: widget.roomCode,
        timers: _timers,
        remaining: _remaining,
        clearLocal: () {
          if (mounted) setState(() => messages = []);
        },
        p2p: _p2p,
        p2pConnected: p2pConnected,
      );
    } else {
      await _history.save(widget.roomCode, messages);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }


  void _listenIncomingCalls() {
    _callSignalSub?.cancel();
    _callSignalSub = DyhanieApi.instance.events.listen((m) {
      if (m['type']?.toString() != 'signal') return;
      final p = m['payload'];
      if (p is! Map) return;

      final room = p['room']?.toString() ?? '';
      if (room != widget.roomCode) return;

      final from = p['from']?.toString() ?? '';
      if (from.isEmpty || from == widget.username) return;

      final kind = p['kind']?.toString() ?? '';
      if (kind != 'call_offer') return;

      // уже в звонке / открываем
      if (callInProgress || _openingCall) return;

      final data = p['data'];
      Map? offer;
      if (data is Map) {
        offer = Map<String, dynamic>.from(data);
      }

      _openIncomingCall(from, offer);
    });
  }

  Future<void> _openIncomingCall(String from, Map? offer) async {
    if (!mounted) return;
    _openingCall = true;
    setState(() {
      callInProgress = true;
      otherUser ??= from;
      callStatusBanner = L.t('call_connecting');
    });
    HapticFeedback.mediumImpact();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          roomCode: widget.roomCode,
          username: widget.username,
          otherUser: from,
          isIncoming: true,
          initialOffer: offer,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      callInProgress = false;
      callStatusBanner = '';
      _openingCall = false;
    });
  }

  void _startCall() {
    final peer = otherUser ?? _otherFromRoomCode();
    if (peer == null || peer.isEmpty) return;
    if (callInProgress || _openingCall) return;

    setState(() {
      otherUser = peer;
      callInProgress = true;
      callStatusBanner = L.t('call_calling');
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          roomCode: widget.roomCode,
          username: widget.username,
          otherUser: peer,
          isIncoming: false,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        callInProgress = false;
        callStatusBanner = '';
      });
    });
  }

  String _ttlLabel(int sec) {
    if (sec == 0) return L.t('ttl_none');
    if (sec == 5) return L.t('sec_5');
    if (sec == 10) return L.t('sec_10');
    if (sec == 15) return L.t('sec_15');
    if (sec == 30) return L.t('sec_30');
    if (sec == 60) return L.t('min_1');
    if (sec == 120) return L.t('min_2');
    if (sec == 300) return L.t('min_5');
    if (sec == 600) return L.t('min_10');
    return '$sec';
  }

  Future<void> _shareHistory() async {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('no_messages'))),
      );
      return;
    }
    if (!p2pConnected || _p2p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('no_p2p_server_blocked'))),
      );
      return;
    }
    var sent = 0;
    for (final m in List<Map<String, dynamic>>.from(messages)) {
      final text = m['text']?.toString() ?? '';
      final imageB64 = m['image']?.toString();
      if (text.isEmpty && imageB64 == null) continue;
      final key =
          'p2p_hist_${DateTime.now().millisecondsSinceEpoch}_$sent';
      final ts = m['timestamp'] is int
          ? m['timestamp'] as int
          : DateTime.now().millisecondsSinceEpoch;
      try {
        _p2p!.send(jsonEncode({
          'type': 'msg',
          'key': key,
          'text': text,
          'timestamp': ts,
          'ttl': 0,
          'replyText': m['replyText'],
          'replyUser': m['replyUser'],
          'image': imageB64,
        }));
        sent++;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.tParams('history_shared', {'n': '$sent'}))),
    );
  }

  void _openSettings() {
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    L.t('settings'),
                    textAlign: TextAlign.center,
                    style: FontService.style(fontSize: 18, color: onSurf),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    L.t('font_size'),
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  Slider(
                    value: messageFontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: messageFontSize.round().toString(),
                    onChanged: (v) {
                      setM(() => messageFontSize = v);
                      setState(() => messageFontSize = v);
                    },
                    onChangeEnd: (_) => _saveChatConfig(),
                  ),
                  Text(
                    L.t('ttl'),
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeOptions.map((sec) {
                      final selected = selectedTime == sec;
                      return ChoiceChip(
                        label: Text(
                          _ttlLabel(sec),
                          style: FontService.style(
                            fontSize: 12,
                            color: selected ? scheme.surface : onSurf,
                          ),
                        ),
                        selected: selected,
                        selectedColor: onSurf,
                        backgroundColor: onSurf.withValues(alpha: 0.08),
                        onSelected: (_) async {
                          setM(() => selectedTime = sec);
                          setState(() => selectedTime = sec);
                          await _saveChatConfig();
                        },
                      );
                    }).toList(),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(AppIcons.image,
                        color: onSurf.withValues(alpha: 0.75)),
                    title: Text(L.t('background'),
                        style: FontService.style(color: onSurf)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final img = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1920,
                      );
                      if (img != null) {
                        final b = await img.readAsBytes();
                        setState(() => backgroundBytes = b);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(AppIcons.share,
                        color: onSurf.withValues(alpha: 0.75)),
                    title: Text(L.t('share_history'),
                        style: FontService.style(color: onSurf)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareHistory();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _visibleMessages {
    if (searchQuery.isEmpty) return messages;
    final q = searchQuery.toLowerCase();
    return messages
        .where((m) => (m['text']?.toString() ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    IncomingCallService.instance.setChatHandlingRoom(null);
    WidgetsBinding.instance.removeObserver(this);
    UnreadChatsService.instance.startListening();
    UnreadChatsService.instance.clear(widget.roomCode);
    _p2pMsgSub?.cancel();
    _p2pStatusSub?.cancel();
    _apiMsgSub?.cancel();
    _p2p?.dispose();
    _callSignalSub?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    _controller.dispose();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _visibleMessages;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        decoration: BoxDecoration(
          color: bg,
          image: backgroundBytes != null
              ? DecorationImage(
                  image: MemoryImage(backgroundBytes!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.55),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: ChatAppBar(
            serverRelayMode: serverRelayMode,
            blockServerMessages: blockServerMessages,
            showSearch: showSearch,
            searchController: _searchCtrl,
            isDirect: _looksLikeDirectDialog(widget.roomCode),
            roomCode: widget.roomCode,
            otherUser: otherUser,
            otherOnline: otherOnline,
            connectionMode: connectionMode,
            wipeOnExit: wipeOnExit,
            myUsername: widget.username,
            myAvatarBytes: myAvatarBytes,
            otherAvatarBytes: otherAvatarBytes,
            onBack: _exitRoom,
            onToggleSearch: () => setState(() {
              showSearch = !showSearch;
              if (!showSearch) {
                searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            onSearchChanged: (v) => setState(() => searchQuery = v.trim()),
            onToggleServerBlock: () async {
              setState(() => serverRelayMode = serverRelayMode.next);
              _updateConnectionMode();
              await _saveChatConfig();
            },
            onCall: _startCall,
            onToggleWipe: () async {
              setState(() => wipeOnExit = !wipeOnExit);
              await _saveChatConfig();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    wipeOnExit ? L.t('wipe_on_exit') : L.t('keep_on_exit'),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onSettings: _openSettings,
          ),
          body: Column(
            children: [
              if (callStatusBanner.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: callInProgress
                      ? Colors.green.withValues(alpha: 0.25)
                      : onSurf.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    callStatusBanner,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: onSurf),
                  ),
                ),
              if (pinned != null)
                Container(
                  width: double.infinity,
                  color: onSurf.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(AppIcons.pin,
                          color: onSurf.withValues(alpha: 0.55), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${pinned!['username']}: ${pinned!['text']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: onSurf.withValues(alpha: 0.75),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          AppIcons.close,
                          size: 16,
                          color: onSurf.withValues(alpha: 0.4),
                        ),
                        onPressed: () => setState(() => pinned = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ChatMessageList(
                  messages: list,
                  myUsername: widget.username,
                  fontSize: messageFontSize,
                  isSavedChat: isSavedChat,
                  selectedTime: selectedTime,
                  remaining: _remaining,
                  otherLastRead: otherLastRead,
                  scrollController: _scroll,
                  onLongPress: _messageActions,
                  onSwipeDelete: _deleteForBoth,
                ),
              ),
              if (typingUser != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '@$typingUser ${L.t('typing')}',
                      style: TextStyle(
                        color: onSurf.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ChatInputBar(
                controller: _controller,
                p2pConnected: p2pConnected,
                blockServerMessages: blockServerMessages,
                replyTo: replyTo,
                onAttach: _attach,
                onEmoji: _openEmoji,
                onSend: () => _send(),
                onClearReply: () => setState(() => replyTo = null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}