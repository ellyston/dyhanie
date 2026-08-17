import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';

import '../models/server_relay_mode.dart';
import '../services/chat_history_service.dart';
import '../services/chat_wipe_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/font_service.dart';
import '../services/locale_service.dart';
import '../services/p2p_service.dart';
import '../services/dyhanie_api.dart';
import '../services/unread_chats_service.dart';
import '../services/avatar_cache.dart';
import '../services/icon_style_service.dart';
import '../services/incoming_call_service.dart';
import '../services/outbox_service.dart';
import '../services/contact_invite_service.dart';
import '../services/media_message_cache.dart';
import '../services/media_chunk_codec.dart';
import '../services/media_chunk_assembler.dart';

import '../widgets/chat_app_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_list.dart';
import '../widgets/chat_media_strip.dart';

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
  final _audioRecorder = AudioRecorder();
  String? _mediaRecordPath;
  DateTime? _mediaRecordStarted;
  bool _flushingOutbox = false;
  bool _mediaActuallyRecording = false;
  bool _micReady = false;
  Timer? _presenceTimer;

  List<Map<String, dynamic>> messages = [];
  final _timers = <String, Timer>{};
  final _remaining = <String, int>{};
  final _knownServerKeys = <String>{};
  final _delivering = <String>{};

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

  /// 0=XS … 4=XL — масштаб пузырей и шрифта в ленте
  int messageSizeLevel = 2;

  static const List<double> messageSizeScales = [
    0.75,
    0.90,
    1.00,
    1.15,
    1.35,
  ];

  double get messageSizeScale =>
      messageSizeScales[messageSizeLevel.clamp(0, 4)];
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
    final me = widget.username.toLowerCase().trim();
    final code = widget.roomCode.toLowerCase().trim();
    final parts = code.split('_');
    if (parts.length == 2) {
      if (parts[0] == me) return parts[1];
      if (parts[1] == me) return parts[0];
      return null;
    }
    if (code.startsWith('${me}_')) return code.substring(me.length + 1);
    if (code.endsWith('_$me')) {
      return code.substring(0, code.length - me.length - 1);
    }
    return otherUser?.toLowerCase().trim();
  }

  Future<void> _loadAvatars() async {
    final prefs = await SharedPreferences.getInstance();

    // --- свой аватар из prefs ---
    Uint8List? mine;
    final myRaw = prefs.getString('avatar');
    if (myRaw != null && myRaw.isNotEmpty) {
      try {
        final clean = myRaw.contains(',') ? myRaw.split(',').last : myRaw;
        mine = base64Decode(clean);
      } catch (_) {}
    }

    // --- аватар собеседника с сервера ---
    Uint8List? otherBytes;
    final other = otherUser ?? _otherFromRoomCode();
    if (other != null && other.isNotEmpty) {
      otherBytes = await AvatarCache.fetch(
        other,
        forceNetwork: true,              // всегда спросить сервер
        bindUsername: widget.username,   // session.bind от своего имени
      );
    }

    if (!mounted) return;
    setState(() {
      myAvatarBytes = mine;
      otherAvatarBytes = otherBytes;     // поле state, не local otherBytes
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
      messageSizeLevel = prefs.getInt('${p}msg_size') ?? 2;
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
    await prefs.setInt('${p}msg_size', messageSizeLevel);
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

      await _hydrateMedia(saved);
      if (!mounted) return;

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
    for (final m in messages) {
      if (m['status'] == 'pending' &&
          (m['msg_type'] == 'voice' || m['msg_type'] == 'video')) {
        unawaited(_deliverWithRetry(m));
      }
    }
  }

  /// base64 → файл на диске; в msg пишем media_path
  Future<void> _persistMediaForMessage(Map<String, dynamic> msg) async {
    final key = msg['key']?.toString() ?? '';
    final media = msg['media']?.toString();
    if (key.isEmpty || media == null || media.isEmpty) return;
    if (msg['media_path'] != null &&
        msg['media_path'].toString().isNotEmpty) {
      return;
    }

    final path = await MediaMessageCache.instance.put(
      roomCode: widget.roomCode,
      msgKey: key,
      base64Data: media,
      msgType: msg['msg_type']?.toString(),
      mime: msg['mime']?.toString(),
    );
    if (path != null) {
      msg['media_path'] = path;
    }
  }

  /// После load истории: media_path → media (base64) для UI / play
  Future<void> _hydrateMedia(List<Map<String, dynamic>> list) async {
    for (final m in list) {
      final existing = m['media']?.toString();
      if (existing != null && existing.isNotEmpty) continue;

      final path = m['media_path']?.toString();
      final b64 = await MediaMessageCache.instance.getBase64(path);
      if (b64 != null) {
        m['media'] = b64;
      }
    }
  }

  /// Сохранить медиа на диск + лёгкий JSON истории
  Future<void> _saveHistory() async {
    if (wipeOnExit) return;
    for (final m in messages) {
      await _persistMediaForMessage(m);
    }
    await _history.save(widget.roomCode, messages);  // сервис истории, не this
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
      otherOnline = false;
    });
    _updateConnectionMode();
    await _loadAvatars();

    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('contacts') ?? [];
    if (!contacts.contains(other)) {
      contacts.add(other);
      await prefs.setStringList('contacts', contacts);
    }

    // 1) Быстро забрать сообщения с сервера
    await _syncServerMessages();
    await UnreadChatsService.instance.clear(widget.roomCode);
    DyhanieApi.instance.chatNudgeAck(room: widget.roomCode).catchError((_) {});

    // 2) Outbox в UI
    await _loadOutboxIntoUi(other);

    // 3) Только потом P2P
    if (!mounted) return;
    _startPresencePolling();
    await _startP2P(other);
    await _clearMyIncomingSignal();
    await _announceInChat(true);
  }

  void _startPresencePolling() {
    _presenceTimer?.cancel();
    final peer = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();
    if (peer == null || peer.isEmpty) return;

    // сразу один раз
    _tickPresence(peer);

    _presenceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickPresence(peer);
    });
  }

  Future<void> _tickPresence(String peer) async {
    try {
      final api = DyhanieApi.instance;
      if (!api.isConnected) await api.connect();
      final me = widget.username.toLowerCase().trim();
      if (api.boundUsername?.toLowerCase() != me) {
        await api.sessionBind(me);
      }

      // «я в этом диалоге»
      await api.chatPresence(room: widget.roomCode, inside: true);

      final online = await api.chatPresenceQuery(
        room: widget.roomCode,
        peer: peer,
      );
      if (!mounted) return;
      if (otherOnline != online) {
        setState(() => otherOnline = online);
      }
    } catch (_) {
      // сеть — не дергаем UI
    }
  }

  void _stopPresencePolling() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    final peer = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();
    DyhanieApi.instance
        .chatPresence(room: widget.roomCode, inside: false)
        .catchError((_) {});
  }

  Future<void> _announceInChat(bool inside) async {
    final other = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();
    if (other == null || other.isEmpty) return;
    try {
      final api = DyhanieApi.instance;
      if (!api.isConnected) await api.connect();
      final me = widget.username.toLowerCase().trim();
      if (api.boundUsername?.toLowerCase() != me) {
        await api.sessionBind(me);
      }
      await api.signal(
        room: widget.roomCode,
        to: other,
        kind: 'chat_presence',
        data: {'in': inside},
      );
    } catch (_) {}
  }

  Future<void> _ensureMic() async {
    final s = await Permission.microphone.status;
    if (s.isGranted) {
      _micReady = true;
      return;
    }
    final r = await Permission.microphone.request();
    _micReady = r.isGranted;
    if (!_micReady && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужен доступ к микрофону')),
      );
    }
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
    _listenChatPresence();
    p2pStatusText = L.t('none');
    connectionMode = L.t('no_connection');
    WidgetsBinding.instance.addObserver(this);
    _loadAvatars();
    _updateConnectionMode();
    _clearMyIncomingSignal();
    Future.delayed(const Duration(milliseconds: 300), _loadSavedHistory);
    Future.delayed(const Duration(milliseconds: 200), _bootstrapPeer);
    _listenServerMessages();
    Future.microtask(_ensureMic);
    _listenIncomingCalls();
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
      Future(() async {
        await _syncServerMessages();
        if (!mounted) return;
        if (otherUser != null && _p2p == null) {
          await _startP2P(otherUser!);
        }
      });
    }
  }

  void _updateConnectionMode() {
    final mode = p2pConnected
        ? 'P2P'
        : (serverRelayMode == ServerRelayMode.open
            ? L.t('via_server')
            : L.t('p2p_only_wait'));
    if (mounted) setState(() => connectionMode = mode);
  }

  void _listenServerMessages() {
    _apiMsgSub?.cancel();
    _apiMsgSub = DyhanieApi.instance.events.listen((m) async {
      if (m['type']?.toString() != 'msg.incoming') return;

      final p = m['payload'];
      if (p is! Map) return;

      final room = p['room']?.toString() ?? '';
      if (room != widget.roomCode) return;

      final from = (p['from']?.toString() ?? '').toLowerCase().trim();
      if (from.isEmpty || from == widget.username.toLowerCase()) return;

      if (await ContactInviteService().isBlocked(from)) return;

      final msgId = p['msg_id']?.toString() ?? '';
      if (msgId.isEmpty || _knownServerKeys.contains(msgId)) return;
      _knownServerKeys.add(msgId);

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
      if (!DyhanieApi.instance.isConnected) {
        await DyhanieApi.instance.connect();
      }
      // sessionBind при необходимости…

      final list = await DyhanieApi.instance.msgSync();
      final forRoom = list.where((p) {
        return (p['room']?.toString() ?? '') == widget.roomCode;
      }).toList();

      forRoom.sort((a, b) {
        final ta = a['created_at'] is int ? a['created_at'] as int : 0;
        final tb = b['created_at'] is int ? b['created_at'] as int : 0;
        return ta.compareTo(tb);
      });

      for (final p in forRoom) {
        _ingestServerMsg(p); // без await
      }
      if (mounted) _scrollEnd();
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
        await _saveHistory();
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

          // ----- чанки media -----
          if (data['type'] == 'media_chunk') {
            unawaited(_handleIncomingMediaChunk(data, other, viaP2p: true));
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
      'media': data['media'],
      'msg_type': data['msg_type'] ?? 'text',
      'duration_ms': data['duration_ms'],
      'mime': data['mime'],
    };
    setState(() => messages = [...messages, msg]);
    if (!isSavedChat && (msg['ttl'] as int) > 0) _startTimer(msg);
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    _scrollEnd();
    _clearMyIncomingSignal();
  }

    Future<void> _handleIncomingMediaChunk(
    Map data,
    String other, {
    required bool viaP2p,
  }) async {
    final map = Map<String, dynamic>.from(data);
    if ((map['from']?.toString() ?? '').isEmpty) {
      map['from'] = other;
    }

    final done = MediaChunkAssembler.instance.add(map);
    if (done == null) return;

    final key = done['key']?.toString() ?? '';
    if (key.isEmpty) return;
    if (_knownServerKeys.contains(key)) return;
    if (messages.any((m) => m['key']?.toString() == key)) return;

    done['username'] =
        (done['username']?.toString().isNotEmpty ?? false)
            ? done['username']
            : other;
    done['p2p'] = viaP2p;
    done['status'] = 'delivered';

    _knownServerKeys.add(key);
    await _persistMediaForMessage(done);

    if (!mounted) return;
    setState(() => messages = [...messages, done]);

    final ttl = done['ttl'] is int ? done['ttl'] as int : 0;
    if (!isSavedChat && ttl > 0) _startTimer(done);

    HapticFeedback.mediumImpact();
    _scrollEnd();
    _clearMyIncomingSignal();
    if (!wipeOnExit) await _saveHistory();
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
    MediaMessageCache.instance.deleteKey(
      roomCode: widget.roomCode,
      msgKey: key,
    );

    if (!mounted) return;
    setState(() {
      messages = messages.where((m) => m['key']?.toString() != key).toList();
      // если чистите _remaining / _timers — как у вас было
    });
    if (!wipeOnExit) {
      _saveHistory();
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


  Future<void> _ingestServerMsg(Map p) async {
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
    final contentType = p['content_type']?.toString() ?? 'text';

    if (contentType == 'media_chunk' ||
        (body.startsWith('{') && body.contains('"media_chunk"'))) {
      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (j['type']?.toString() == 'media_chunk') {
          j['from'] = from;
          final done =
              MediaChunkAssembler.instance.add(Map<String, dynamic>.from(j));
          DyhanieApi.instance.msgAckRead(msgId).catchError((_) {});
          if (done != null) {
            if ((done['username']?.toString() ?? '').isEmpty) {
              done['username'] = from;
            }
            final doneKey = done['key']?.toString() ?? msgId;
            if (!_knownServerKeys.contains(doneKey) &&
                !messages.any((m) => m['key']?.toString() == doneKey)) {
              _knownServerKeys.add(doneKey);
              await _persistMediaForMessage(done);
              if (!mounted) return;
              setState(() => messages = [...messages, done]);
              final ttl = done['ttl'] is int ? done['ttl'] as int : 0;
              if (!isSavedChat && ttl > 0) _startTimer(done);
              _scrollEnd();
              UnreadChatsService.instance.clear(widget.roomCode);
              if (!wipeOnExit) await _saveHistory();
            }
          }
          return;
        }
      } catch (_) {}
    }
  

    // ----- обычное сообщение -----
    String text = body;
    String? image;
    String? media;
    String msgType = 'text';
    int? durationMs;
    String? replyText;
    String? replyUser;
    int ttl = selectedTime;

    try {
      if (body.startsWith('{')) {
        final j = jsonDecode(body) as Map<String, dynamic>;
        if (j['type']?.toString() == 'media_chunk') {
          // на всякий случай
          return;
        }
        text = j['text']?.toString() ?? '';
        image = j['image']?.toString();
        media = j['media']?.toString();
        msgType = j['msg_type']?.toString() ?? 'text';
        durationMs =
            j['duration_ms'] is int ? j['duration_ms'] as int : null;
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
      'media': media,
      'msg_type': msgType,
      'duration_ms': durationMs,
      'status': 'delivered',
    };

    _knownServerKeys.add(msgId);

    await _persistMediaForMessage(msg);

    if (!mounted) return;
    setState(() => messages = [...messages, msg]);
    if (!isSavedChat && ttl > 0) _startTimer(msg);
    _scrollEnd();

    DyhanieApi.instance.msgAckRead(msgId).catchError((_) {});
    UnreadChatsService.instance.clear(widget.roomCode);

    if (!wipeOnExit) {
      await _saveHistory();
    }
  }

  Future<void> _send({
    String? imageB64,
    String? mediaB64,
    String msgType = 'text',
    int? durationMs,
    String? mime,
  }) async {
    final text = _controller.text.trim();
    if (text.isEmpty && imageB64 == null && mediaB64 == null) return;

    final other = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();
    final canP2P = p2pConnected && _p2p != null && _p2p!.isOpen;
    final canServer = serverRelayMode == ServerRelayMode.open;
    final useOutbox = !canP2P &&
        (serverRelayMode == ServerRelayMode.hard ||
            serverRelayMode == ServerRelayMode.soft);

    // Нет канала сейчас — всё равно кладём локально и ретраим (для media/text)
    final noChannelNow = !canP2P && !canServer && !useOutbox;
    final noOtherForServer =
        (canServer || useOutbox) && (other == null || other.isEmpty);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final key = canP2P
        ? 'p2p_$ts'
        : (useOutbox ? 'ob_$ts' : 'srv_$ts');

    final effectiveType = mediaB64 != null
        ? msgType
        : (imageB64 != null ? 'image' : 'text');

    // outbox (hard/soft без P2P) — как раньше
    if (useOutbox && other != null && other.isNotEmpty) {
      try {
        final ob = await _outbox.add(
          from: widget.username,
          to: other,
          text: text,
          ttl: selectedTime,
          image: imageB64 ?? mediaB64,
          replyText: replyTo?['text']?.toString(),
          replyUser: replyTo?['username']?.toString(),
        );
        // key можно заменить на ob.id, если outbox так устроен
        // key = ob.id;
      } catch (_) {}
    }

    final msg = <String, dynamic>{
      'key': key,
      'text': text,
      'username': widget.username,
      'timestamp': ts,
      'ttl': selectedTime,
      'p2p': canP2P,
      'pending': true,
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
      'image': imageB64,
      'media': mediaB64,
      'msg_type': effectiveType,
      'duration_ms': durationMs,
      'mime': mime,
      'status': 'pending',
    };

    // 1) UI
    if (mounted) {
      setState(() {
        messages = [...messages, msg];
        replyTo = null;
      });
    }
    if (!isSavedChat && selectedTime > 0) _startTimer(msg);
    _scrollEnd();

    // 2) Локальный кэш (до сети)
    await _persistMediaForMessage(msg);
    if (!wipeOnExit) {
      await _saveHistory();
    }

    _controller.clear();
    HapticFeedback.lightImpact();

    // 3) Доставка в фоне, без SnackBar об ошибке
    if (noChannelNow || (canServer && noOtherForServer && !canP2P)) {
      // некому/некуда — остаётся pending, retry сам выйдет когда появится канал
      debugPrint('send: no channel/other yet, pending $key');
    }
    unawaited(_deliverWithRetry(msg));
    unawaited(_notifyDirectIncoming());
  }

  Future<void> _deliverWithRetry(Map<String, dynamic> msg) async {
    final key = msg['key']?.toString() ?? '';
    if (key.isEmpty) return;
    if (_delivering.contains(key)) return;
    _delivering.add(key);

    const maxAttempts = 40;
    const gap = Duration(seconds: 3);

    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (!mounted) return;

        final ok = await _tryDeliverOnce(msg);
        if (ok) {
          if (!mounted) return;
          setState(() {
            final i = messages.indexWhere((m) => m['key'] == key);
            if (i >= 0) {
              messages[i]['status'] = 'sent';
              messages[i]['pending'] = false;
            }
          });
          if (!wipeOnExit) await _saveHistory();
          return;
        }
        await Future<void>.delayed(gap);
      }
      debugPrint('deliver give up $key');
    } finally {
      _delivering.remove(key);
    }
  }

    Future<bool> _tryDeliverOnce(Map<String, dynamic> msg) async {
    final key = msg['key']?.toString() ?? '';
    final text = msg['text']?.toString() ?? '';
    final imageB64 = msg['image']?.toString();
    final mediaB64 = msg['media']?.toString();
    final msgType = msg['msg_type']?.toString() ?? 'text';
    final durationMs =
        msg['duration_ms'] is int ? msg['duration_ms'] as int : null;
    final mime = msg['mime']?.toString();
    final ts = msg['timestamp'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final ttl = msg['ttl'] is int ? msg['ttl'] as int : selectedTime;
    final other = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();

    final canP2P = p2pConnected && _p2p != null && _p2p!.isOpen;
    final canServer = serverRelayMode == ServerRelayMode.open;

    if (!canP2P && !canServer) return false;
    if (canServer && (other == null || other.isEmpty) && !canP2P) {
      return false;
    }

    // voice / video — всегда чанками (total может быть 1)
    if (mediaB64 != null &&
        mediaB64.isNotEmpty &&
        (msgType == 'voice' || msgType == 'video')) {
      return _deliverChunked(
        mediaId: key,
        mediaB64: mediaB64,
        msgType: msgType,
        mime: mime,
        durationMs: durationMs,
        ttl: ttl,
        replyText: msg['replyText']?.toString(),
        replyUser: msg['replyUser']?.toString(),
        canP2P: canP2P,
        canServer: canServer,
        other: other,
      );
    }

    // крупное фото в image
    if (imageB64 != null && imageB64.isNotEmpty) {
      try {
        final clean = imageB64.contains(',')
            ? imageB64.split(',').last.trim()
            : imageB64;
        final raw = Uint8List.fromList(base64Decode(clean));
        if (MediaChunkCodec.needsChunking(raw)) {
          return _deliverChunked(
            mediaId: key,
            mediaB64: imageB64,
            msgType: 'image',
            mime: mime ?? 'image/jpeg',
            durationMs: null,
            ttl: ttl,
            replyText: msg['replyText']?.toString(),
            replyUser: msg['replyUser']?.toString(),
            canP2P: canP2P,
            canServer: canServer,
            other: other,
          );
        }
      } catch (_) {}
    }

    // текст / мелкое фото — одним пакетом
    var p2pOk = false;
    var serverOk = false;

    if (canP2P) {
      try {
        _p2p!.send(jsonEncode({
          'type': 'msg',
          'key': key,
          'text': text,
          'timestamp': ts,
          'ttl': ttl,
          'replyText': msg['replyText'],
          'replyUser': msg['replyUser'],
          'image': imageB64,
          'media': mediaB64,
          'msg_type': msgType,
          'duration_ms': durationMs,
          'mime': mime,
        }));
        p2pOk = true;
      } catch (_) {
        p2pOk = false;
      }
    }

    if (canServer && other != null && other.isNotEmpty) {
      try {
        final body = jsonEncode({
          'text': text,
          'ttl': ttl,
          'replyText': msg['replyText'],
          'replyUser': msg['replyUser'],
          'image': imageB64,
          'media': mediaB64,
          'msg_type': msgType,
          'duration_ms': durationMs,
          'mime': mime,
        });
        final contentType = imageB64 != null ? 'image' : 'text';

        final api = DyhanieApi.instance;
        if (!api.isConnected) await api.connect();
        final me = widget.username.toLowerCase().trim();
        if (api.boundUsername?.toLowerCase() != me) {
          await api.sessionBind(me);
        }
        await api.msgSend(
          room: widget.roomCode,
          to: other,
          msgId: key,
          body: body,
          contentType: contentType,
        );
        _knownServerKeys.add(key);
        serverOk = true;
      } catch (_) {
        serverOk = false;
      }
    }

    if (canP2P && canServer) return p2pOk || serverOk;
    if (canP2P) return p2pOk;
    if (canServer) return serverOk;
    return false;
  }

  Future<bool> _deliverChunked({
    required String mediaId,
    required String mediaB64,
    required String msgType,
    String? mime,
    int? durationMs,
    required int ttl,
    String? replyText,
    String? replyUser,
    required bool canP2P,
    required bool canServer,
    String? other,
  }) async {
    late Uint8List bytes;
    try {
      final clean =
          mediaB64.contains(',') ? mediaB64.split(',').last.trim() : mediaB64;
      bytes = Uint8List.fromList(base64Decode(clean));
    } catch (_) {
      return false;
    }
    if (bytes.isEmpty) return false;

    final parts = MediaChunkCodec.needsChunking(bytes)
        ? MediaChunkCodec.splitBase64(bytes)
        : [base64Encode(bytes)];
    final total = parts.length;

    var anyOk = false;
    var allOk = true;

    for (var i = 0; i < total; i++) {
      final env = MediaChunkCodec.envelope(
        mediaId: mediaId,
        index: i,
        total: total,
        msgType: msgType,
        dataB64: parts[i],
        mime: mime,
        durationMs: durationMs,
        ttl: ttl,
        from: widget.username,
        replyText: replyText,
        replyUser: replyUser,
      );

      var chunkOk = false;

      if (canP2P) {
        try {
          _p2p!.send(jsonEncode(env));
          chunkOk = true;
        } catch (_) {}
      }

      if (canServer && other != null && other.isNotEmpty) {
        try {
          final api = DyhanieApi.instance;
          if (!api.isConnected) await api.connect();
          final me = widget.username.toLowerCase().trim();
          if (api.boundUsername?.toLowerCase() != me) {
            await api.sessionBind(me);
          }
          await api.msgSend(
            room: widget.roomCode,
            to: other,
            msgId: '${mediaId}_$i',
            body: jsonEncode(env),
            contentType: 'media_chunk',
          );
          chunkOk = true;
        } catch (_) {}
      }

      if (chunkOk) {
        anyOk = true;
      } else {
        allOk = false;
      }
    }

    // успех попытки: все куски ушли хотя бы одним каналом
    return allOk && anyOk;
  }

  Future<bool> _deliverMediaBytes({
    required String mediaId,
    required Uint8List bytes,
    required String msgType,
    String? mime,
    int? durationMs,
    required int ttl,
    String? replyText,
    String? replyUser,
  }) async {
    final other = (otherUser ?? _otherFromRoomCode())?.toLowerCase().trim();
    final canP2P = p2pConnected && _p2p != null && _p2p!.isOpen;
    final canServer = serverRelayMode == ServerRelayMode.open &&
        other != null &&
        other.isNotEmpty;

    if (!canP2P && !canServer) return false;

    final parts = MediaChunkCodec.needsChunking(bytes)
        ? MediaChunkCodec.splitBase64(bytes)
        : [base64Encode(bytes)];

    final total = parts.length;
    var allOk = true;

    for (var i = 0; i < total; i++) {
      final env = MediaChunkCodec.envelope(
        mediaId: mediaId,
        index: i,
        total: total,
        msgType: msgType,
        dataB64: parts[i],
        mime: mime,
        durationMs: durationMs,
        ttl: ttl,
        from: widget.username,
        replyText: replyText,
        replyUser: replyUser,
      );
      // один кусок без нарезки — можно слать type: msg со старым форматом;
      // для единообразия всегда media_chunk с total==1

      var ok = false;

      if (canP2P) {
        try {
          _p2p!.send(jsonEncode(env));
          ok = true;
        } catch (_) {}
      }

      if (canServer) {
        try {
          final api = DyhanieApi.instance;
          if (!api.isConnected) await api.connect();
          final me = widget.username.toLowerCase().trim();
          if (api.boundUsername?.toLowerCase() != me) {
            await api.sessionBind(me);
          }
          final chunkId = '${mediaId}_$i';
          await api.msgSend(
            room: widget.roomCode,
            to: other!,
            msgId: chunkId, // уникальный на кусок
            body: jsonEncode(env),
            contentType: 'media_chunk',
          );
          ok = true;
        } catch (_) {}
      }

      if (!ok) allOk = false;
      // можно break и retry с index i
    }
    return allOk;
  }

  Future<void> _sendViaServer({
    required String key,
    required String other,
    required String text,
    String? imageB64,
    String? mediaB64,
    required String msgType,
    int? durationMs,
    String? mime,
  }) async {
    final body = jsonEncode({
      'text': text,
      'ttl': selectedTime,
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
      'image': imageB64,
      'media': mediaB64,
      'msg_type': msgType,
      'duration_ms': durationMs,
      'mime': mime,
    });

    try {
      final api = DyhanieApi.instance;
      if (!api.isConnected) {
        await api.connect();
      }
      final me = widget.username.toLowerCase().trim();
      if (api.boundUsername?.toLowerCase() != me) {
        await api.sessionBind(me);
      }

      await api.msgSend(
        room: widget.roomCode,
        to: other,
        msgId: key,
        body: body,
        contentType: msgType,
      );
      _knownServerKeys.add(key);
    } catch (e) {
      if (mounted) {
        setState(() {
          final i = messages.indexWhere((m) => m['key'] == key);
          if (i >= 0) messages[i]['status'] = 'error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сервер: $e')),
        );
      }
    }
  }

  Future<void> _onMediaRecordStart(MediaStripMode mode) async {
    if (mode == MediaStripMode.video) {
      await _recordVideoMessage();
      return;
    }

    if (!_micReady) {
      await _ensureMic();
      if (!_micReady) return;
      // Право только что выдали — не начинаем запись в этом же жесте
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Микрофон разрешён. Зажмите полоску ещё раз'),
          ),
        );
      }
      return;
    }

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 22050,
        ),
        path: path, // ← не _mediaRecordPath!
      );

      _mediaRecordPath = path;
      _mediaRecordStarted = DateTime.now();
      _mediaActuallyRecording = true;
    } catch (e) {
      _mediaActuallyRecording = false;
      _mediaRecordPath = null;
      _mediaRecordStarted = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Старт записи: $e')),
        );
      }
    }
  }

  Future<void> _recordVideoMessage() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 10),
      );
      if (file == null) return;

      // Сжатие ~360p / LowQuality
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final path = info?.path;
      if (path == null || path.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось сжать видео')),
          );
        }
        return;
      }

      final compressed = File(path);
      final bytes = await compressed.readAsBytes();
      if (bytes.isEmpty) return;

      if (bytes.length > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${L.t('file_too_big')} (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
              ),
            ),
          );
        }
        return;
      }

      final durationMs = info?.duration?.round() ?? 0; // если API даёт Duration
      // в части версий: info.duration — double в ms → durationMs = info.duration?.toInt()

      await _send(
        mediaB64: base64Encode(bytes),
        msgType: 'video',
        durationMs: durationMs is int ? durationMs : 0,
        mime: 'video/mp4',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Видео: $e')),
        );
      }
    } finally {
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
    }
  }
  
  Future<void> _onMediaRecordEnd(MediaStripMode mode) async {
    if (mode == MediaStripMode.video) return;

    if (!_mediaActuallyRecording) {
      // Не было start (диалог прав / ошибка) — тихо выходим, без «файл пуст»
      return;
    }
    _mediaActuallyRecording = false;

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Стоп записи: $e')),
        );
      }
      _mediaRecordPath = null;
      _mediaRecordStarted = null;
      return;
    }

    path ??= _mediaRecordPath;
    final started = _mediaRecordStarted;
    _mediaRecordPath = null;
    _mediaRecordStarted = null;

    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл записи пуст')),
        );
      }
      return;
    }

    final ms = started == null
        ? 0
        : DateTime.now().difference(started).inMilliseconds;

    if (ms < 400) {
      try {
        await File(path).delete();
      } catch (_) {}
      return; // короткое — без пугающего SnackBar
    }

    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}

    if (bytes.isEmpty || bytes.length > 500000) {
      if (mounted && bytes.length > 500000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.t('file_too_big'))),
        );
      }
      return;
    }

    await _send(
      mediaB64: base64Encode(bytes),
      msgType: 'voice',
      durationMs: ms.clamp(0, 60000),
      mime: 'audio/m4a',
    );
  }

  Future<void> _onMediaRecordCancel(MediaStripMode mode) async {
    _mediaActuallyRecording = false;
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    final p = _mediaRecordPath;
    _mediaRecordPath = null;
    _mediaRecordStarted = null;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
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
    _presenceTimer?.cancel();
    _presenceTimer = null;

    // UI уходит сразу
    if (!mounted) return;
    Navigator.pop(context);

    // дальше без ожидания в UI-потоке навигации
    unawaited(_cleanupAfterExit());
  }

  Future<void> _cleanupAfterExit() async {
    try {
      await DyhanieApi.instance
          .chatPresence(room: widget.roomCode, inside: false)
          .timeout(const Duration(milliseconds: 400));
    } catch (_) {}
    try {
      if (!wipeOnExit) {
        await _saveHistory();
      } else {
        await MediaMessageCache.instance.clearRoom(widget.roomCode);
        await _history.clear(widget.roomCode);
      }
    } catch (_) {}
    try {
      _p2p?.dispose();
    } catch (_) {}
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

  void _listenChatPresence() {
    DyhanieApi.instance.events.listen((m) {
      if (m['type']?.toString() != 'signal') return;
      final p = m['payload'];
      if (p is! Map) return;
      if ((p['room']?.toString() ?? '') != widget.roomCode) return;
      final from = (p['from']?.toString() ?? '').toLowerCase();
      final me = widget.username.toLowerCase();
      if (from.isEmpty || from == me) return;
      if ((p['kind']?.toString() ?? '') != 'chat_presence') return;

      final data = p['data'];
      final inside = data is Map && data['in'] == true;
      if (!mounted) return;
      setState(() => otherOnline = inside);
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: onSurf.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // —— Поиск ——
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      showSearch ? Icons.close : Icons.search,
                      color: onSurf.withValues(alpha: 0.75),
                    ),
                    title: Text(
                      showSearch ? L.t('close') : L.t('search_messages'),
                      style: FontService.style(color: onSurf),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        showSearch = !showSearch;
                        if (!showSearch) {
                          searchQuery = '';
                          _searchCtrl.clear();
                        }
                      });
                    },
                  ),

                  // —— Режим сервера ——
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      serverRelayMode == ServerRelayMode.open
                          ? AppIcons.cloud
                          : AppIcons.cloudOff,
                      color: serverRelayMode == ServerRelayMode.open
                          ? onSurf.withValues(alpha: 0.75)
                          : Colors.redAccent,
                    ),
                    title: Text(
                      switch (serverRelayMode) {
                        ServerRelayMode.open => L.t('server_relay_open'),
                        ServerRelayMode.soft => L.t('server_relay_soft'),
                        ServerRelayMode.hard => L.t('server_relay_hard'),
                      },
                      style: FontService.style(color: onSurf),
                    ),
                    subtitle: Text(
                      L.t('via_server'),
                      style: FontService.style(
                        color: onSurf.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                    onTap: () async {
                      setM(() => serverRelayMode = serverRelayMode.next);
                      setState(() {});
                      _updateConnectionMode();
                      await _saveChatConfig();
                    },
                  ),

                  const Divider(height: 24),

                  // —— Шрифт ——
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

                  // —— TTL ——
                  Text(
                    selectedTime <= 0
                        ? 'Время жизни: не исчезать'
                        : 'Время жизни: ${selectedTime ~/ 60} м ${selectedTime % 60} с',
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  Slider(
                    value: selectedTime.clamp(0, 600).toDouble(),
                    min: 0,
                    max: 600, // 10 минут
                    divisions: 60, // шаг 10 с
                    label: selectedTime <= 0
                        ? '∞'
                        : (selectedTime < 60
                            ? '$selectedTime с'
                            : '${selectedTime ~/ 60}:${(selectedTime % 60).toString().padLeft(2, '0')}'),
                    onChanged: (v) {
                      final t = v.round();
                      setM(() => selectedTime = t);
                      setState(() => selectedTime = t);
                    },
                    onChangeEnd: (_) => _saveChatConfig(),
                  ),

                  const SizedBox(height: 8),

                  const SizedBox(height: 16),
                  Text(
                    'Размер сообщений',
                    style: FontService.style(
                      color: onSurf.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(5, (i) {
                      const labels = ['XS', 'S', 'M', 'L', 'XL'];
                      final selected = messageSizeLevel == i;
                      return ChoiceChip(
                        label: Text(
                          labels[i],
                          style: FontService.style(
                            fontSize: 12,
                            color: selected ? scheme.surface : onSurf,
                          ),
                        ),
                        selected: selected,
                        selectedColor: onSurf,
                        backgroundColor: onSurf.withValues(alpha: 0.08),
                        onSelected: (_) async {
                          setM(() => messageSizeLevel = i);
                          setState(() => messageSizeLevel = i);
                          await _saveChatConfig();
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 8),

                  // —— Фон ——
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

                  // —— История ——
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
    _stopPresencePolling();
    IncomingCallService.instance.setChatHandlingRoom(null);
    WidgetsBinding.instance.removeObserver(this);
    UnreadChatsService.instance.startListening();
    UnreadChatsService.instance.clear(widget.roomCode);
    _p2pMsgSub?.cancel();
    _p2pStatusSub?.cancel();
    _apiMsgSub?.cancel();
    _p2p?.dispose();
    _callSignalSub?.cancel();
    _audioRecorder.dispose();
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
                  videoSizeLevel: messageSizeLevel,
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatMediaStrip(
                    onRecordStart: _onMediaRecordStart,
                    onRecordEnd: _onMediaRecordEnd,
                    onRecordCancel: _onMediaRecordCancel,
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
            ],
          ),
        ),
      ),
    );
  }
}