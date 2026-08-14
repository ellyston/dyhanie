import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Клиент к своему signalа VPS
class DyhanieApi {
  DyhanieApi._();
  static final DyhanieApi instance = DyhanieApi._();

  /// Пока один URL; позже — список и выбор по RTT.
  static const String defaultWsUrl = 'wss://signal.dyhanie.su';

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

  Future<void> usernameDelete(String username) async {
    final r = await request(
      'username.delete',
      payload: {'username': username.toLowerCase().trim()},
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'DELETE_FAIL');
    }
  }

  Future<void> avatarSet(String base64Data) async {
    final clean = base64Data.contains(',')
        ? base64Data.split(',').last.trim()
        : base64Data.trim();
    final r = await request(
      'avatar.set',
      payload: {'data': clean},
      timeout: const Duration(seconds: 60),
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'AVATAR_SET_FAIL');
    }
  }

  Future<String?> avatarGet(String username) async {
    final m = await avatarGetWithMeta(username);
    return m?['data']?.toString();
  }

    Future<Map<String, dynamic>?> avatarGetWithMeta(String username) async {
    final r = await request(
      'avatar.get',
      payload: {'username': username.toLowerCase().trim()},
      timeout: const Duration(seconds: 45), // base64 может быть тяжёлым
    );
    if (r['ok'] != true) return null;
    final p = r['payload'];
    if (p is! Map) return null;
    final data = p['data']?.toString();
    if (data == null || data.isEmpty) return null;
    return {
      'data': data,
      'updated_at': p['updated_at'],
    };
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

  Future<List<Map<String, dynamic>>> msgSync() async {
    final r = await request('msg.sync');
    if (r['ok'] != true) return [];
    final payload = r['payload'];
    if (payload is! Map) return [];
    final list = payload['messages'] as List? ?? [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> msgAckRead(String msgId) async {
    final r = await request('msg.ackRead', payload: {'msg_id': msgId});
    if (r['ok'] != true) throw Exception(r['error']?['code'] ?? 'ACK_FAIL');
  }

  // ---- contacts ----

  Future<void> contactInvite(String toUsername) async {
    final r = await request(
      'contact.invite',
      payload: {'to': toUsername},
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'INVITE_FAIL');
    }
  }

  Future<void> contactAccept(String fromUsername) async {
    final r = await request(
      'contact.accept',
      payload: {'from': fromUsername},
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'ACCEPT_FAIL');
    }
  }

  Future<void> contactDecline(String fromUsername) async {
    final r = await request(
      'contact.decline',
      payload: {'from': fromUsername},
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'DECLINE_FAIL');
    }
  }

  Future<void> contactCancel(String toUsername) async {
    final r = await request(
      'contact.cancel',
      payload: {'to': toUsername},
    );
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'CANCEL_FAIL');
    }
  }
  
  Future<Map<String, dynamic>> contactInvitesList() async {
    final r = await request('contact.invites_list');
    if (r['ok'] != true) {
      return {'incoming': <Map>[], 'outgoing': <Map>[], 'badge': 0};
    }
    final payload = r['payload'];
    if (payload is! Map) {
      return {'incoming': <Map>[], 'outgoing': <Map>[], 'badge': 0};
    }
    final incoming = (payload['incoming'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final outgoing = (payload['outgoing'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final badge = payload['badge'] is int
        ? payload['badge'] as int
        : incoming.length;
    return {
      'incoming': incoming,
      'outgoing': outgoing,
      'badge': badge,
    };
  }
  
  Future<void> chatNudge({required String to, required String room}) async {
    final r = await request('chat.nudge', payload: {
      'to': to.toLowerCase(),
      'room': room,
    });
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'NUDGE_FAIL');
    }
  }

  Future<void> chatNudgeAck({required String room}) async {
    final r = await request('chat.nudge_ack', payload: {'room': room});
    if (r['ok'] != true) {
      throw Exception(r['error']?['code'] ?? 'NUDGE_ACK_FAIL');
    }
  }

  Future<List<Map<String, dynamic>>> usernameSearch(
    String query, {
    int limit = 20,
  }) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final r = await request(
      'username.search',
      payload: {
        'query': q,
        'limit': limit,
      },
    );

    if (r['ok'] != true) {
      final code = r['error']?['code']?.toString() ?? 'SEARCH_FAIL';
      throw Exception(code);
    }

    final payload = r['payload'];
    if (payload is! Map) return [];

    final list = payload['users'] as List? ?? [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) {
          final u = m['username']?.toString().toLowerCase().trim();
          return u != null && u.isNotEmpty;
        })
        .toList();
  }

  Future<Map<String, dynamic>> chatNudgesList() async {
    final r = await request('chat.nudges_list');
    if (r['ok'] != true) {
      return {'nudges': <Map<String, dynamic>>[], 'badge': 0};
    }
    final p = r['payload'];
    if (p is! Map) {
      return {'nudges': <Map<String, dynamic>>[], 'badge': 0};
    }
    final nudges = (p['nudges'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final badge = p['badge'] is int ? p['badge'] as int : nudges.length;
    return {'nudges': nudges, 'badge': badge};
  }
  

}