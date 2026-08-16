import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Локальный кэш voice/video (и при желании image) рядом с историей чата.
class MediaMessageCache {
  MediaMessageCache._();
  static final instance = MediaMessageCache._();

  Future<Directory> _dirForRoom(String roomCode) async {
    final root = await getApplicationDocumentsDirectory();
    final safe = roomCode.replaceAll(RegExp(r'[^\w\-\.]'), '_');
    final dir = Directory('${root.path}/chat_media/$safe');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _path(String roomCode, String msgKey, String ext) async {
    final dir = await _dirForRoom(roomCode);
    final safeKey = msgKey.replaceAll(RegExp(r'[^\w\-\.]'), '_');
    return '${dir.path}/$safeKey.$ext';
  }

  String _extFor(String? msgType, String? mime) {
    if (msgType == 'voice' || (mime?.startsWith('audio') ?? false)) {
      return 'm4a';
    }
    if (msgType == 'video' || (mime?.startsWith('video') ?? false)) {
      return 'mp4';
    }
    if (msgType == 'image' || (mime?.startsWith('image') ?? false)) {
      return 'jpg';
    }
    return 'bin';
  }

  /// Сохранить base64 с диска; вернуть абсолютный путь.
  Future<String?> put({
    required String roomCode,
    required String msgKey,
    required String base64Data,
    String? msgType,
    String? mime,
  }) async {
    if (base64Data.isEmpty || msgKey.isEmpty) return null;
    try {
      final clean =
          base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64Decode(clean);
      if (bytes.isEmpty) return null;
      final ext = _extFor(msgType, mime);
      final path = await _path(roomCode, msgKey, ext);
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Прочитать файл → base64 (для UI / play).
  Future<String?> getBase64(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> deleteKey({
    required String roomCode,
    required String msgKey,
  }) async {
    try {
      final dir = await _dirForRoom(roomCode);
      if (!await dir.exists()) return;
      final safeKey = msgKey.replaceAll(RegExp(r'[^\w\-\.]'), '_');
      await for (final e in dir.list()) {
        if (e is File && e.path.contains(safeKey)) {
          await e.delete();
        }
      }
    } catch (_) {}
  }

  /// Вся медиа папки комнаты (wipe / clear history).
  Future<void> clearRoom(String roomCode) async {
    try {
      final dir = await _dirForRoom(roomCode);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}