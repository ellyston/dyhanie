import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'p2p_service.dart';
import 'dyhanie_api.dart';
import 'transport_mode_service.dart';
import 'media_chunk_codec.dart';

/// Единая точка отправки (text / media) + чанки на P2P и server.
class MessageSendService {
  MessageSendService._();
  static final MessageSendService instance = MessageSendService._();

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Map<String, dynamic> buildTextMessage({
    required String myUsername,
    required String text,
    required int ttlSeconds,
    Map<String, dynamic>? replyTo,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final t = TransportModeService.instance;
    final key = t.isP2p ? 'p2p_$ts' : 'srv_$ts';

    return <String, dynamic>{
      'key': key,
      'text': text.trim(),
      'username': myUsername,
      'timestamp': ts,
      'ttl': ttlSeconds,
      'p2p': t.isP2p,
      'pending': true,
      'status': 'pending',
      'msg_type': 'text',
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
    };
  }

  Map<String, dynamic> buildMediaMessage({
    required String myUsername,
    required String msgType, // voice | video | image
    required String mediaBase64,
    required String mime,
    int? durationMs,
    required int ttlSeconds,
    Map<String, dynamic>? replyTo,
    String? text,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final t = TransportModeService.instance;
    final key = t.isP2p ? 'p2p_$ts' : 'srv_$ts';
    final isImage = msgType == 'image';

    return <String, dynamic>{
      'key': key,
      'text': text?.trim() ?? '',
      'username': myUsername,
      'timestamp': ts,
      'ttl': ttlSeconds,
      'p2p': t.isP2p,
      'pending': true,
      'status': 'pending',
      'msg_type': msgType,
      'mime': mime,
      'duration_ms': durationMs,
      if (isImage) 'image': mediaBase64 else 'media': mediaBase64,
      'replyText': replyTo?['text'],
      'replyUser': replyTo?['username'],
    };
  }

  // ---------------------------------------------------------------------------
  // Public deliver + retry
  // ---------------------------------------------------------------------------

  Future<bool> deliver({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool p2pOpen,
  }) async {
    final msgType = msg['msg_type']?.toString() ?? 'text';
    final imageB64 = msg['image']?.toString();
    final mediaB64 = msg['media']?.toString();
    final payloadB64 = (mediaB64 != null && mediaB64.isNotEmpty)
        ? mediaB64
        : imageB64;

    // Есть бинарный payload → возможно чанки
    if (payloadB64 != null && payloadB64.isNotEmpty) {
      Uint8List? bytes;
      try {
        final clean = payloadB64.contains(',')
            ? payloadB64.split(',').last.trim()
            : payloadB64;
        bytes = Uint8List.fromList(base64Decode(clean));
      } catch (_) {
        return false;
      }

      if (MediaChunkCodec.needsChunking(bytes)) {
        return _deliverChunked(
          msg: msg,
          bytes: bytes,
          roomCode: roomCode,
          myUsername: myUsername,
          otherUser: otherUser,
          p2p: p2p,
          p2pOpen: p2pOpen,
        );
      }
    }

    // Крупный текст (редко) — тоже чанками как msg_type text
    final text = msg['text']?.toString() ?? '';
    if (msgType == 'text' && text.length > MediaChunkCodec.rawChunkSize) {
      final bytes = Uint8List.fromList(utf8.encode(text));
      if (MediaChunkCodec.needsChunking(bytes)) {
        return _deliverChunked(
          msg: msg,
          bytes: bytes,
          roomCode: roomCode,
          myUsername: myUsername,
          otherUser: otherUser,
          p2p: p2p,
          p2pOpen: p2pOpen,
          forceMsgType: 'text',
          textInEnvelope: true,
        );
      }
    }

    return _deliverSingle(
      msg: msg,
      roomCode: roomCode,
      myUsername: myUsername,
      otherUser: otherUser,
      p2p: p2p,
      p2pOpen: p2pOpen,
    );
  }

  Future<bool> deliverWithRetry({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool Function() isP2pOpen,
    void Function(Map<String, dynamic> updated)? onSent,
  }) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final ok = await deliver(
        msg: msg,
        roomCode: roomCode,
        myUsername: myUsername,
        otherUser: otherUser,
        p2p: p2p,
        p2pOpen: isP2pOpen(),
      );
      if (ok) {
        msg['status'] = 'sent';
        msg['pending'] = false;
        msg['p2p'] = TransportModeService.instance.isP2p;
        onSent?.call(msg);
        return true;
      }
      await Future<void>.delayed(Duration(seconds: 2 + (attempt ~/ 3)));
    }
    return false;
  }

  // Старые имена — алиасы, чтобы chat_screen не ломать
  Future<bool> deliverText({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool p2pOpen,
  }) =>
      deliver(
        msg: msg,
        roomCode: roomCode,
        myUsername: myUsername,
        otherUser: otherUser,
        p2p: p2p,
        p2pOpen: p2pOpen,
      );

  Future<bool> deliverMedia({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool p2pOpen,
  }) =>
      deliver(
        msg: msg,
        roomCode: roomCode,
        myUsername: myUsername,
        otherUser: otherUser,
        p2p: p2p,
        p2pOpen: p2pOpen,
      );

  Future<bool> deliverMediaWithRetry({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool Function() isP2pOpen,
    void Function(Map<String, dynamic> updated)? onSent,
  }) =>
      deliverWithRetry(
        msg: msg,
        roomCode: roomCode,
        myUsername: myUsername,
        otherUser: otherUser,
        p2p: p2p,
        isP2pOpen: isP2pOpen,
        onSent: onSent,
      );

  // ---------------------------------------------------------------------------
  // Single packet
  // ---------------------------------------------------------------------------

  Future<bool> _deliverSingle({
    required Map<String, dynamic> msg,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool p2pOpen,
  }) async {
    final key = msg['key']?.toString() ?? '';
    if (key.isEmpty) return false;

    final msgType = msg['msg_type']?.toString() ?? 'text';
    final text = msg['text']?.toString() ?? '';
    final imageB64 = msg['image']?.toString();
    final mediaB64 = msg['media']?.toString();
    final mime = msg['mime']?.toString();
    final durationMs =
        msg['duration_ms'] is int ? msg['duration_ms'] as int : null;
    final ts = msg['timestamp'] as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final ttl = msg['ttl'] is int ? msg['ttl'] as int : 0;
    final t = TransportModeService.instance;

    if (t.isP2p) {
      if (!p2pOpen || p2p == null) return false;
      try {
        p2p.send(jsonEncode({
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
        return true;
      } catch (_) {
        return false;
      }
    }

    final other = otherUser?.toLowerCase().trim();
    if (other == null || other.isEmpty) return false;

    final api = DyhanieApi.instance;
    try {
      if (!api.isConnected) await api.connect();
      final me = myUsername.toLowerCase().trim();
      if (api.boundUsername?.toLowerCase() != me) {
        await api.sessionBind(me);
      }

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

      final contentType = (msgType == 'voice' || msgType == 'video')
          ? msgType
          : (imageB64 != null && imageB64.isNotEmpty ? 'image' : 'text');

      await api.msgSend(
        room: roomCode,
        to: other,
        msgId: key,
        body: body,
        contentType: contentType,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Chunked (P2P + server)
  // ---------------------------------------------------------------------------

  Future<bool> _deliverChunked({
    required Map<String, dynamic> msg,
    required Uint8List bytes,
    required String roomCode,
    required String myUsername,
    required String? otherUser,
    P2PService? p2p,
    required bool p2pOpen,
    String? forceMsgType,
    bool textInEnvelope = false,
  }) async {
    final mediaId = msg['key']?.toString() ?? '';
    if (mediaId.isEmpty || bytes.isEmpty) return false;

    final msgType =
        forceMsgType ?? (msg['msg_type']?.toString() ?? 'video');
    final mime = msg['mime']?.toString();
    final durationMs =
        msg['duration_ms'] is int ? msg['duration_ms'] as int : null;
    final ttl = msg['ttl'] is int ? msg['ttl'] as int : 0;
    final replyText = msg['replyText']?.toString();
    final replyUser = msg['replyUser']?.toString();

    final parts = MediaChunkCodec.splitBase64(bytes);
    final total = parts.length;
    if (total == 0) return false;

    final t = TransportModeService.instance;
    final canP2P = t.isP2p;
    final canServer = t.isServer;

    if (canP2P && (!p2pOpen || p2p == null)) return false;
    if (canServer) {
      final other = otherUser?.toLowerCase().trim();
      if (other == null || other.isEmpty) return false;
    }

    var allOk = true;
    var anyOk = false;

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
        from: myUsername,
        replyText: replyText,
        replyUser: replyUser,
      );
      // для гигантского текста кладём признак в envelope (опционально)
      if (textInEnvelope) {
        env['payload_kind'] = 'utf8_text';
      }

      var chunkOk = false;

      if (canP2P && p2p != null && p2pOpen) {
        try {
          p2p.send(jsonEncode(env));
          chunkOk = true;
        } catch (_) {}
      }

      if (canServer) {
        final other = otherUser!.toLowerCase().trim();
        try {
          final api = DyhanieApi.instance;
          if (!api.isConnected) await api.connect();
          final me = myUsername.toLowerCase().trim();
          if (api.boundUsername?.toLowerCase() != me) {
            await api.sessionBind(me);
          }
          await api.msgSend(
            room: roomCode,
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
        // обрыв серии — нет смысла слать хвост
        break;
      }

      // лёгкий throttle, чтобы не забить DC / WS
      if (i + 1 < total) {
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }
    }

    return allOk && anyOk;
  }
}