import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../services/chat_wipe_service.dart';
import '../services/chat_history_service.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_app_bar.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/chat_message_list.dart';

import '../services/dialog_signal_service.dart';
import '../services/p2p_service.dart';
import 'call_screen.dart';

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
  String p2pStatusText = 'нет';
  bool blockServerMessages = false;
  String connectionMode = 'нет связи';

  int selectedTime = 30;
  double messageFontSize = 16;
  Uint8List? backgroundBytes;
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
  bool wipeOnExit = true;

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
        // не затираем, если уже что-то пришло с сервера — дополняем
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
    WidgetsBinding.instance.addObserver(this);
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
        ? 'P2P'
        : (otherUser != null
            ? (blockServerMessages ? 'только P2P (ждём)' : 'сервер')
            : 'нет связи');
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
      if (mounted) setState(() => p2pStatusText = 'ошибка: $e');
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
    _readSub =
        _db.child('rooms').child(widget.roomCode).child('read').onValue.listen((event) {
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
    _callSub =
        _db.child('rooms').child(widget.roomCode).child('call').onValue.listen((event) {
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
          callStatusBanner =
              from == widget.username ? 'Вызов...' : 'Входящий звонок';
        }
        if (status == 'accepted') callStatusBanner = 'Идёт звонок';
        if (status == 'rejected') callStatusBanner = 'Сброшен';
        if (status == 'ended') callStatusBanner = 'Звонок завершён';
        if (status == 'no_answer') callStatusBanner = 'Не ответил';
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
        title: const Text('Входящий звонок', style: TextStyle(color: Colors.white)),
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
            child: const Text('Отклонить', style: TextStyle(color: Colors.redAccent)),
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
            child: const Text('Принять', style: TextStyle(color: Colors.greenAccent)),
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
    _saveSub =
        _db.child('rooms').child(widget.roomCode).child('meta').onValue.listen((event) {
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
        const SnackBar(content: Text('Нет P2P, сервер заблокирован')),
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
        const SnackBar(content: Text('Файл слишком большой')),
      );
      return;
    }
    await _send(imageB64: base64Encode(bytes));
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
              title: const Text('Ответить', style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => replyTo = msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin, color: Colors.white70),
              title: const Text('Закрепить', style: TextStyle(color: Colors.white)),
              onTap: () {
                _pinMessage(msg);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('Копировать', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: msg['text']?.toString() ?? ''),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')),
                );
              },
            ),
            if (msg['username'] == widget.username)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title:
                    const Text('Удалить у всех', style: TextStyle(color: Colors.redAccent)),
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

  String _fmtTime(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusIcon(Map msg) {
    if (msg['username'] != widget.username) return const SizedBox.shrink();
    final ts = msg['timestamp'] as int? ?? 0;
    final read = otherLastRead != null && otherLastRead! >= ts;
    return Icon(
      read ? Icons.done_all : Icons.done,
      size: 14,
      color: read ? Colors.lightBlueAccent : Colors.white38,
    );
  }

  Future<void> _exitRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Выйти?', style: TextStyle(color: Colors.white)),
        content: Text(
          wipeOnExit
              ? 'Диалог будет полностью очищен (сервер и P2P).'
              : 'Диалог сохранится.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _wipe.leavePresence(
      roomCode: widget.roomCode,
      username: widget.username,
    );

    if (wipeOnExit) {
      // 🔴 красный — стереть историю и сервер/P2P
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
      // 🟢 зелёный — сохранить сообщения на устройство
      await _history.save(widget.roomCode, messages);
    }

    await Future.delayed(const Duration(milliseconds: 300));

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

  void _openTime() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: timeOptions.map((sec) {
            final label = sec == 0
                ? 'Не исчезать'
                : (sec < 60 ? '$sec сек' : '${sec ~/ 60} мин');
            return ChoiceChip(
              label: Text(label),
              selected: selectedTime == sec,
              onSelected: (_) {
                setState(() => selectedTime = sec);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Настройки', style: TextStyle(color: Colors.white, fontSize: 18)),
                Slider(
                  value: messageFontSize,
                  min: 12,
                  max: 24,
                  divisions: 12,
                  activeColor: Colors.white,
                  onChanged: (v) {
                    setM(() => messageFontSize = v);
                    setState(() => messageFontSize = v);
                  },
                ),
                SwitchListTile(
                  title: const Text(
                    'Блокировать сервер',
                    style: TextStyle(color: Colors.white70),
                  ),
                  value: blockServerMessages,
                  onChanged: (v) {
                    setM(() => blockServerMessages = v);
                    setState(() => blockServerMessages = v);
                    _updateConnectionMode();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
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
                  icon: const Icon(Icons.image, color: Colors.white70),
                  label: const Text('Фон', style: TextStyle(color: Colors.white70)),
                ),
                if (!isSavedChat)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _db.child('rooms').child(widget.roomCode).child('meta').update({
                        'saveRequestedBy': widget.username,
                        'saved': false,
                      });
                    },
                    child: const Text('Предложить сохранить чат'),
                  ),
              ],
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
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
           showSearch: showSearch,
           searchController: _searchCtrl,
           isDirect: _looksLikeDirectDialog(widget.roomCode),
           roomCode: widget.roomCode,
           otherUser: otherUser,
           otherOnline: otherOnline,
           connectionMode: connectionMode,
           blockServerMessages: blockServerMessages,
           wipeOnExit: wipeOnExit,
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
           onTimer: _openTime,
           onToggleWipe: () {
             setState(() => wipeOnExit = !wipeOnExit);
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text(
                   wipeOnExit
                      ? 'При выходе диалог будет полностью очищен'
                       : 'При выходе диалог сохранится',
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
                      : Colors.white10,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    callStatusBanner,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              if (pinned != null)
                Container(
                  width: double.infinity,
                  color: Colors.white10,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${pinned!['username']}: ${pinned!['text']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, size: 16, color: Colors.white38),
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
                  color: Colors.white10,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '@$saveRequestedBy предлагает сохранить чат',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _db
                            .child('rooms')
                            .child(widget.roomCode)
                            .child('meta')
                            .update({'saveRequestedBy': null}),
                        child:
                            const Text('Нет', style: TextStyle(color: Colors.white54)),
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
                        child: const Text(
                          'Да',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!p2pConnected)
                Container(
                  width: double.infinity,
                  color: Colors.white10,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Text(
                    otherUser == null
                        ? 'Ожидание собеседника...'
                        : 'P2P: $p2pStatusText | $connectionMode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                      '@$typingUser печатает...',
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
              
              ChatInputBar(
                controller: _controller,
                p2pConnected: p2pConnected,
                blockServerMessages: blockServerMessages,
                replyTo: replyTo,
                onAttach: _attach,
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