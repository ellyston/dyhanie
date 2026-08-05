import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Клиент к своему signaling/API на VPS (без Firebase).
class DyhanieApi {
  DyhanieApi._();
  static final DyhanieApi instance = DyhanieApi._();

  /// Пока один URL; позже — список и выбор по RTT.
  static const String defaultWsUrl = 'ws://82.24.110.215:8787';

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  final _waiters = <String, Completer<Map<String, dynamic>>>{};
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  String? boundUsername;
  bool get isConnected => _ch != null;

  /// События без ответа на id: signal, msg.incoming, room.join_requested, ...
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> connect({String url = defaultWsUrl}) async {
    await disconnect();
    final uri = Uri.parse(url);
    _ch = WebSocketChannel.connect(uri);
    _sub = _ch!.stream.listen(
      _onData,
      onError: (e) => _failAll(e),
      onDone: () => _failAll(StateError('ws closed')),
    );
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    boundUsername = null;
    _failAll(StateError('disconnected'));
  }

  void _failAll(Object e) {
    for (final c in _waiters.values) {
      if (!c.isCompleted) c.completeError(e);
    }
    _waiters.clear();
  }

  void _onData(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final id = map['id']?.toString();
      if (id != null && _waiters.containsKey(id)) {
        final c = _waiters.remove(id)!;
        if (!c.isCompleted) c.complete(map);
        return;
      }
      _events.add(map);
    } catch (_) {}
  }

  String _newId() =>
      'c_${DateTime.now().microsecondsSinceEpoch}_${_waiters.length}';

  Future<Map<String, dynamic>> request(
    String type, {
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_ch == null) {
      throw StateError('not connected — call connect() first');
    }
    final id = _newId();
    final c = Completer<Map<String, dynamic>>();
    _waiters[id] = c;
    _ch!.sink.add(jsonEncode({
      'v': 1,
      'id': id,
      'type': type,
      'payload': payload ?? {},
    }));
    return c.future.timeout(timeout, onTimeout: () {
      _waiters.remove(id);
      throw TimeoutException('timeout $type');
    });
  }

  // ---- username ----

  Future<bool> usernameExists(String username) async {
    final r = await request('username.check', payload: {'username': username});
    if (r['ok'] != true) return false;
    return r['payload']?['exists'] == true;
  }

  Future<void> usernameRegister(String username) async {
    final r =
        await request('username.register', payload: {'username': username});
    if (r['ok'] == true) return;
    final code = r['error']?['code']?.toString() ?? 'ERROR';
    throw Exception(code);
  }

  Future<void> usernameRename(String from, String to) async {
    final r = await request(
      'username.rename',
      payload: {'from': from, 'to': to},
    );
    if (r['ok'] == true) return;
    throw Exception(r['error']?['code'] ?? 'ERROR');
  }

  // ---- session ----

  Future<void> sessionBind(String username) async {
    final r =
        await request('session.bind', payload: {'username': username});
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'BIND_FAILED');
    }
    boundUsername = username;
  }

  // ---- rooms (следующий шаг можно вызывать отсюда) ----

  Future<void> roomPin(String room) async {
    final r = await request('room.pin', payload: {'room': room});
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'PIN_FAIL');
  }

  Future<void> roomJoin(String room) async {
    final r = await request('room.join', payload: {'room': room});
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'JOIN_FAIL');
  }

  Future<void> roomAdmit(String room, String username) async {
    final r = await request(
      'room.admit',
      payload: {'room': room, 'username': username},
    );
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'ADMIT_FAIL');
  }

  Future<void> roomDeny(String room, String username) async {
    final r = await request(
      'room.deny',
      payload: {'room': room, 'username': username},
    );
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'DENY_FAIL');
  }

  // ---- signal / msg (подключим в P2P и chat) ----

  Future<void> signal({
    required String room,
    required String to,
    required String kind,
    required dynamic data,
  }) async {
    final r = await request(
      'signal',
      payload: {'room': room, 'to': to, 'kind': kind, 'data': data},
    );
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'SIGNAL_FAIL');
  }

  Future<void> msgSend({
    required String room,
    required String to,
    required String msgId,
    required String body,
    String contentType = 'text',
  }) async {
    final r = await request(
      'msg.send',
      payload: {
        'room': room,
        'to': to,
        'msg_id': msgId,
        'body': body,
        'content_type': contentType,
      },
    );
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'MSG_FAIL');
  }

  Future<void> msgAckRead(String msgId) async {
    final r = await request('msg.ackRead', payload: {'msg_id': msgId});
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'ACK_FAIL');
  }
}