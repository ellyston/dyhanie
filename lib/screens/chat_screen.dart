import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_history_service.dart';
import '../services/chat_wipe_service.dart';
import '../services/dialog_signal_service.dart';
import '../services/locale_service.dart';
import '../services/p2p_service.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_list.dart';
import 'call_screen.dart';
import 'emoji_picker_screen.dart';
import '../services/font_service.dart';

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
  final _db = FirebaseDatabase.instance.ref();
  final _picker = ImagePicker();
  final _scroll = ScrollController();
  final _dialogSignals = DialogSignalService();
  final _wipe = ChatWipeService();
  final _history = ChatHistoryService();

  List<Map<String, dynamic>> messages = [];
  final _timers = <String, Timer>{};
  final _remaining = <String, int>{};
  final _knownServerKeys = <String>{};

  StreamSubscription? _typingSub;
  StreamSubscription? _saveSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _callSub;
  StreamSubscription? _msgSub;
  StreamSubscription? _delSub;
  StreamSubscription? _pinSub;
  StreamSubscription? _readSub;
  StreamSubscription? _p2pMsgSub;
  StreamSubscription? _p2pStatusSub;

  P2PService? _p2p;
  bool p2pConnected = false;
  String p2pStatusText = '';
  String connectionMode = '';

  bool blockServerMessages = true;
  int selectedTime = 0;
  bool wipeOnExit = false; // зелёный = сохранять

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
  bool _incomingDialogShown = false;
  bool showSearch = false;
  String searchQuery = '';
  Map<String, dynamic>? pinned;
  Map<String, dynamic>? replyTo;
  int? otherLastRead;
  bool callInProgress = false;
  String callStatusBanner = '';

  /// true = красный: при выходе чистим сервер + P2P
  /// false = зелёный: диалог сохраняется

  final timeOptions = [0, 5, 10, 15, 30, 60, 120, 300, 600];
  Timer? _typingThrottle;

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
        mine = base64Decode(myRaw);
      } catch (_) {}
    }


    Uint8List? otherBytes;
    final other = otherUser ?? _otherFromRoomCode();
    if (other != null) {
      final raw = prefs.getString('avatar_$other');
      if (raw != null && raw.isNotEmpty) {
        try {
          otherBytes = base64Decode(raw);
        } catch (_) {}
      }
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
    setState(() {
      wipeOnExit = prefs.getBool('${p}wipe') ?? false;
      blockServerMessages = prefs.getBool('${p}block_server') ?? true;
      selectedTime = prefs.getInt('${p}ttl') ?? 0;
      messageFontSize = prefs.getDouble('${p}font') ?? 16.0;
    });
    _updateConnectionMode();
  }

  Future<void> _saveChatConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final p = _prefsPrefix;
    await prefs.setBool('${p}wipe', wipeOnExit);
    await prefs.setBool('${p}block_server', blockServerMessages);
    await prefs.setInt('${p}ttl', selectedTime);
    await prefs.setDouble('${p}font', messageFontSize);
  }


  Future<void> _clearMyIncomingSignal() async {
    if (!_looksLikeDirectDialog(widget.roomCode)) return;
    final other = _otherFromRoomCode();
    if (other == null) return;
    try {
      await _dialogSignals.clearPendingIn(
        from: other,
        to: widget.username,
      );
    } catch (_) {}
  }

  Future<void> _loadSavedHistory() async {
    try {
      final saved = await _history.load(widget.roomCode);
      if (!mounted) return;
      if (saved.isEmpty) return;

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

  @override
  void initState() {
    super.initState();
    _loadChatConfig();
    p2pStatusText = L.t('none');
    connectionMode = L.t('no_connection');
    WidgetsBinding.instance.addObserver(this);
    _loadAvatars();
    _setOnline(true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _setOnline(true);
    });
    _listenTyping();
    _listenSave();
    _listenPresence();
    _listenCalls();
    _listenMessages();
    _listenDeletes();
    _listenPin();
    _listenRead();
    _controller.addListener(_onTyping);
    _updateConnectionMode();
    _clearMyIncomingSignal();
    Future.delayed(const Duration(milliseconds: 300), _loadSavedHistory);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
      _clearMyIncomingSignal();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }

  void _updateConnectionMode() {
    final mode = p2pConnected
        ? L.t('p2p_connected')
        : (otherUser != null
            ? (blockServerMessages ? L.t('p2p_only_wait') : L.t('via_server'))
            : L.t('no_connection'));
    if (mounted) setState(() => connectionMode = mode);
  }

  void _setOnline(bool online) {
    final ref = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('presence')
        .child(widget.username);
    if (online) {
      ref.set(true);
      ref.onDisconnect().remove();
    } else {
      ref.remove();
    }
  }

  void _listenPresence() {
    final roomPresence =
        _db.child('rooms').child(widget.roomCode).child('presence');
    roomPresence.child(widget.username).set(true);
    roomPresence.child(widget.username).onDisconnect().remove();

    _presenceSub = roomPresence.onValue.listen((event) async {
      if (event.snapshot.value == null) {
        setState(() {
          otherUser = null;
          otherOnline = false;
        });
        _updateConnectionMode();
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      String? other;
      bool online = false;
      data.forEach((k, v) {
        if (k.toString() != widget.username) {
          other = k.toString();
          online = v == true;
        }
      });

      setState(() {
        otherUser = other;
        otherOnline = online;
      });
      _updateConnectionMode();
      _loadAvatars();

      if (other != null) {
        final name = other!;
        final prefs = await SharedPreferences.getInstance();
        final contacts = prefs.getStringList('contacts') ?? [];
        if (!contacts.contains(name)) {
          contacts.add(name);
          await prefs.setStringList('contacts', contacts);
        }
        _startP2P(name);
        await _clearMyIncomingSignal();
      }
    });
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
      if (s == 'p2p_open') {
        if (mounted) {
          setState(() => p2pConnected = true);
          _updateConnectionMode();
        }
        return;
      }

      final bad = s.contains('failed') ||
          s.contains('Failed') ||
          s.contains('closed') ||
          s.contains('Closed') ||
          s == 'ice_failed';
      if (!bad) return;

      if (mounted) {
        setState(() => p2pConnected = false);
        _updateConnectionMode();
      }
      _p2pMsgSub?.cancel();
      _p2pStatusSub?.cancel();
      _p2p?.dispose();
      _p2p = null;

      Future.delayed(const Duration(seconds: 3), () {
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
    final key =
        data['key']?.toString() ?? 'p2p_${DateTime.now().millisecondsSinceEpoch}';
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
    _markRead();
    _clearMyIncomingSignal();
  }

  void _listenMessages() {
    _msgSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('messages')
        .onChildAdded
        .listen((event) {
      if (p2pConnected) return;
      if (blockServerMessages) return;
      if (event.snapshot.value == null) return;

      final key = event.snapshot.key ?? '';
      if (key.isEmpty || _knownServerKeys.contains(key)) return;
      _knownServerKeys.add(key);

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      data['key'] = key;
      data['p2p'] = false;
      if (data['username'] == widget.username) return;

      setState(() => messages = [...messages, data]);
      if (!isSavedChat && ((data['ttl'] as int?) ?? 0) > 0) _startTimer(data);
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      _scrollEnd();
      _markRead();
      _clearMyIncomingSignal();
    });
  }

  void _listenDeletes() {
    _delSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('deletes')
        .onChildAdded
        .listen((event) {
      final key = event.snapshot.value?.toString();
      if (key != null) _removeLocal(key);
    });
  }

  void _listenPin() {
    _pinSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('meta')
        .child('pinned')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) {
        setState(() => pinned = null);
        return;
      }
      setState(
        () => pinned = Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  void _listenRead() {
    _readSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('read')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      data.forEach((k, v) {
        if (k.toString() != widget.username) {
          setState(
            () => otherLastRead = v is int ? v : int.tryParse(v.toString()),
          );
        }
      });
    });
  }

  void _markRead() {
    _db
        .child('rooms')
        .child(widget.roomCode)
        .child('read')
        .child(widget.username)
        .set(DateTime.now().millisecondsSinceEpoch);
  }

  void _listenCalls() {
    _callSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('call')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) {
        setState(() {
          callInProgress = false;
          callStatusBanner = '';
        });
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final status = data['status']?.toString() ?? '';
      final to = data['to']?.toString();
      final from = data['from']?.toString();

      setState(() {
        callInProgress = status == 'ringing' || status == 'accepted';
        if (status == 'ringing') {
          callStatusBanner = from == widget.username
              ? L.t('calling')
              : L.t('incoming_call');
        }
        if (status == 'accepted') callStatusBanner = L.t('call_in_progress');
        if (status == 'rejected') callStatusBanner = L.t('call_rejected');
        if (status == 'ended') callStatusBanner = L.t('call_ended');
        if (status == 'no_answer') callStatusBanner = L.t('no_answer');
      });

      if (status == 'ringing' &&
          to == widget.username &&
          from != null &&
          !_incomingDialogShown) {
        _incomingDialogShown = true;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        _showIncomingCall(from);
      }

      if (status == 'ended' || status == 'rejected' || status == 'no_answer') {
        _incomingDialogShown = false;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => callStatusBanner = '');
        });
      }
    });
  }

  void _showIncomingCall(String from) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          L.t('incoming_call'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text('@$from', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              _db
                  .child('rooms')
                  .child(widget.roomCode)
                  .child('call')
                  .update({'status': 'rejected'});
              _incomingDialogShown = false;
              Navigator.pop(ctx);
            },
            child: Text(
              L.t('decline_call'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              _db
                  .child('rooms')
                  .child(widget.roomCode)
                  .child('call')
                  .update({'status': 'accepted'});
              _incomingDialogShown = false;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    roomCode: widget.roomCode,
                    username: widget.username,
                    otherUser: from,
                    isIncoming: true,
                  ),
                ),
              );
            },
            child: Text(
              L.t('accept_call'),
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _onTyping() {
    _typingThrottle?.cancel();
    _db
        .child('rooms')
        .child(widget.roomCode)
        .child('typing')
        .child(widget.username)
        .set(true);
    _typingThrottle = Timer(const Duration(milliseconds: 1500), () {
      _db
          .child('rooms')
          .child(widget.roomCode)
          .child('typing')
          .child(widget.username)
          .remove();
    });
  }

  void _listenTyping() {
    _typingSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('typing')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) {
        setState(() => typingUser = null);
        return;
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      String? other;
      data.forEach((k, v) {
        if (k.toString() != widget.username && v == true) other = k.toString();
      });
      setState(() => typingUser = other);
    });
  }

  void _listenSave() {
    _saveSub = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('meta')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final saved = data['saved'] == true;
      final by = data['saveRequestedBy']?.toString();
      setState(() {
        isSavedChat = saved;
        if (by != null && by != widget.username && !saved) {
          saveRequestIncoming = true;
          saveRequestedBy = by;
        } else {
          saveRequestIncoming = false;
          saveRequestedBy = null;
        }
      });
    });
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
      setState(() => messages = messages.where((m) => m['key'] != key).toList());
    }
  }

  void _deleteForBoth(String key) {
    _removeLocal(key);
    _db.child('rooms').child(widget.roomCode).child('messages').child(key).remove();
    _db.child('rooms').child(widget.roomCode).child('deletes').push().set(key);
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

  Future<void> _send({String? imageB64}) async {
    final text = _controller.text.trim();
    if (text.isEmpty && imageB64 == null) return;

    final canP2P = p2pConnected && _p2p != null;
    final canServer = !blockServerMessages;
    if (!canP2P && !canServer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.t('no_p2p_server_blocked'))),
      );
      return;
    }

    final viaP2P = canP2P;
    final key =
        '${viaP2P ? 'p2p' : 'srv'}_${DateTime.now().millisecondsSinceEpoch}';
    final ts = DateTime.now().millisecondsSinceEpoch;

    final msg = {
      'key': key,
      'text': text,
      'username': widget.username,
      'timestamp': ts,
      'ttl': selectedTime,
      'p2p': viaP2P,
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
      'image': imageB64,
      'status': 'sent',
    };

    setState(() {
      messages = [...messages, msg];
      replyTo = null;
    });
    if (!isSavedChat && selectedTime > 0) _startTimer(msg);
    _scrollEnd();

    final payload = {
      'type': 'msg',
      'key': key,
      'text': text,
      'timestamp': ts,
      'ttl': selectedTime,
      'replyText': msg['replyText'],
      'replyUser': msg['replyUser'],
      'image': imageB64,
    };

    if (viaP2P) {
      _p2p!.send(jsonEncode(payload));
    } else {
      final ref =
          _db.child('rooms').child(widget.roomCode).child('messages').push();
      _knownServerKeys.add(ref.key ?? key);
      await ref.set({
        'text': text,
        'username': widget.username,
        'timestamp': ts,
        'ttl': selectedTime,
        'p2p': false,
        'replyText': msg['replyText'],
        'replyUser': msg['replyUser'],
        'image': imageB64,
      });
    }

    await _notifyDirectIncoming();

    _controller.clear();
    _db
        .child('rooms')
        .child(widget.roomCode)
        .child('typing')
        .child(widget.username)
        .remove();
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
    _db.child('rooms').child(widget.roomCode).child('meta').child('pinned').set({
      'text': msg['text'],
      'username': msg['username'],
      'key': msg['key'],
    });
  }

  void _messageActions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: Text(L.t('reply'), style: const TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => replyTo = msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin, color: Colors.white70),
              title: Text(
                L.t('pin_message'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                _pinMessage(msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: Text(L.t('copy'), style: const TextStyle(color: Colors.white)),
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
                leading: const Icon(Icons.delete, color: Colors.redAccent),
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

  /// Выход без подтверждающего диалога
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

    await Future.delayed(const Duration(milliseconds: 200));

    final empty = await _wipe.isRoomEmpty(widget.roomCode);
    if (wipeOnExit && empty) {
      await _wipe.removeRoom(widget.roomCode);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _startCall() {
    if (otherUser == null) return;
    if (callInProgress) return;

    _db.child('rooms').child(widget.roomCode).child('webrtc').remove();

    _db.child('rooms').child(widget.roomCode).child('call').set({
      'from': widget.username,
      'to': otherUser,
      'status': 'ringing',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    Future.delayed(const Duration(seconds: 30), () async {
      final snap =
          await _db.child('rooms').child(widget.roomCode).child('call').get();
      if (snap.value is Map && (snap.value as Map)['status'] == 'ringing') {
        await _db
            .child('rooms')
            .child(widget.roomCode)
            .child('call')
            .update({'status': 'no_answer'});
      }
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          roomCode: widget.roomCode,
          username: widget.username,
          otherUser: otherUser,
          isIncoming: false,
        ),
      ),
    );
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
    final canP2P = p2pConnected && _p2p != null;
    final canServer = !blockServerMessages;
    if (!canP2P && !canServer) {
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
      final viaP2P = canP2P;
      final key =
          '${viaP2P ? 'p2p' : 'srv'}_hist_${DateTime.now().millisecondsSinceEpoch}_$sent';
      final ts = m['timestamp'] is int
          ? m['timestamp'] as int
          : DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'type': 'msg',
        'key': key,
        'text': text,
        'timestamp': ts,
        'ttl': 0,
        'replyText': m['replyText'],
        'replyUser': m['replyUser'],
        'image': imageB64,
      };
      try {
        if (viaP2P) {
          _p2p!.send(jsonEncode(payload));
        } else {
          final ref = _db
              .child('rooms')
              .child(widget.roomCode)
              .child('messages')
              .push();
          _knownServerKeys.add(ref.key ?? key);
          await ref.set({
            'text': text,
            'username': widget.username,
            'timestamp': ts,
            'ttl': 0,
            'p2p': false,
            'replyText': m['replyText'],
            'replyUser': m['replyUser'],
            'image': imageB64,
          });
        }
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: onSurf.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        L.t('font_preview_sample'),
                        style: FontService.style(
                          color: onSurf,
                          fontSize: messageFontSize,
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.image_outlined,
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
                    leading: Icon(Icons.ios_share_outlined,
                        color: onSurf.withValues(alpha: 0.75)),
                    title: Text(L.t('share_history'),
                        style: FontService.style(color: onSurf)),
                    subtitle: Text(
                      L.t('share_history_hint'),
                      style: FontService.style(
                        fontSize: 12,
                        color: onSurf.withValues(alpha: 0.5),
                      ),
                    ),
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
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    _typingSub?.cancel();
    _saveSub?.cancel();
    _presenceSub?.cancel();
    _callSub?.cancel();
    _msgSub?.cancel();
    _delSub?.cancel();
    _pinSub?.cancel();
    _readSub?.cancel();
    _p2pMsgSub?.cancel();
    _p2pStatusSub?.cancel();
    _p2p?.dispose();
    _typingThrottle?.cancel();
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
            // ... все параметры как были — не меняй
            showSearch: showSearch,
            searchController: _searchCtrl,
            isDirect: _looksLikeDirectDialog(widget.roomCode),
            roomCode: widget.roomCode,
            otherUser: otherUser,
            otherOnline: otherOnline,
            connectionMode: connectionMode,
            blockServerMessages: blockServerMessages,
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
            onToggleServerBlock: () {
              setState(() => blockServerMessages = !blockServerMessages);
              _updateConnectionMode();
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
                      Icon(Icons.push_pin,
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
                          Icons.close,
                          size: 16,
                          color: onSurf.withValues(alpha: 0.4),
                        ),
                        onPressed: () => _db
                            .child('rooms')
                            .child(widget.roomCode)
                            .child('meta')
                            .child('pinned')
                            .remove(),
                      ),
                    ],
                  ),
                ),
              if (saveRequestIncoming)
                Container(
                  color: onSurf.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          L.tParams(
                            'save_chat_offer',
                            {'name': '$saveRequestedBy'},
                          ),
                          style: TextStyle(color: onSurf),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _db
                            .child('rooms')
                            .child(widget.roomCode)
                            .child('meta')
                            .update({'saveRequestedBy': null}),
                        child: Text(
                          L.t('no'),
                          style: TextStyle(
                            color: onSurf.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _db
                              .child('rooms')
                              .child(widget.roomCode)
                              .child('meta')
                              .update({
                            'saved': true,
                            'saveRequestedBy': null,
                          });
                          for (final t in _timers.values) {
                            t.cancel();
                          }
                          _timers.clear();
                          setState(() => isSavedChat = true);
                        },
                        child: Text(
                          L.t('yes'),
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
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