import 'dart:convert';
import 'dart:typed_data';

class MediaChunkCodec {
  /// Сырые байты на кусок (~32KB base64).
  static const int rawChunkSize = 24 * 1024;

  static bool needsChunking(Uint8List bytes) =>
      bytes.length > rawChunkSize;

  static List<String> splitBase64(Uint8List bytes) {
    final out = <String>[];
    for (var i = 0; i < bytes.length; i += rawChunkSize) {
      final end = (i + rawChunkSize < bytes.length)
          ? i + rawChunkSize
          : bytes.length;
      out.add(base64Encode(bytes.sublist(i, end)));
    }
    return out;
  }

  static Uint8List joinBase64(List<String?> parts) {
    final builder = BytesBuilder(copy: false);
    for (final p in parts) {
      if (p == null) {
        throw StateError('missing chunk');
      }
      builder.add(base64Decode(p.contains(',') ? p.split(',').last : p));
    }
    return builder.toBytes();
  }

  static Map<String, dynamic> envelope({
    required String mediaId,
    required int index,
    required int total,
    required String msgType,
    required String dataB64,
    String? mime,
    int? durationMs,
    int? ttl,
    String? from,
    String? replyText,
    String? replyUser,
  }) {
    return {
      'type': 'media_chunk',
      'media_id': mediaId,
      'index': index,
      'total': total,
      'msg_type': msgType,
      'mime': mime,
      'duration_ms': durationMs,
      'ttl': ttl,
      'from': from,
      'replyText': replyText,
      'replyUser': replyUser,
      'data': dataB64,
    };
  }
}