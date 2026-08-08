import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'dyhanie_api.dart';

class AvatarCache {
  static String keyFor(String username) =>
      'avatar_${username.toLowerCase().trim()}';

  static String _tsKey(String username) =>
      'avatar_ts_${username.toLowerCase().trim()}';

  static Future<void> save(
    String username,
    String base64Data, {
    int? updatedAt,
  }) async {
    final clean = base64Data.contains(',')
        ? base64Data.split(',').last.trim()
        : base64Data.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final u = username.toLowerCase().trim();
    await prefs.setString(keyFor(u), clean);
    if (updatedAt != null) {
      await prefs.setInt(_tsKey(u), updatedAt);
    }
  }

  static Future<void> saveBytes(
    String username,
    Uint8List bytes, {
    int? updatedAt,
  }) async {
    await save(username, base64Encode(bytes), updatedAt: updatedAt);
  }

  static Future<Uint8List?> load(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(username));
    if (raw == null || raw.isEmpty) return null;
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  /// Кэш, при необходимости обновление с сервера.
  static Future<Uint8List?> fetch(
    String username, {
    bool forceNetwork = false,
  }) async {
    final u = username.toLowerCase().trim();
    if (u.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final localTs = prefs.getInt(_tsKey(u)) ?? 0;

    if (!forceNetwork) {
      final cached = await load(u);
      // если кэша нет — ниже сеть; если есть — всё равно сверим ts
      if (cached == null) {
        // fall through to network
      } else {
        // быстрый путь: сеть только для сверки ts (ниже)
      }
    }

    try {
      if (!DyhanieApi.instance.isConnected) {
        await DyhanieApi.instance.connect();
      }

      final r = await DyhanieApi.instance.avatarGetWithMeta(u);
      if (r == null) {
        return await load(u);
      }

      final b64 = r['data'] as String?;
      final remoteTs = r['updated_at'] is int
          ? r['updated_at'] as int
          : int.tryParse('${r['updated_at']}') ?? 0;

      if (b64 == null || b64.isEmpty) return await load(u);

      if (forceNetwork || remoteTs > localTs || localTs == 0) {
        await save(u, b64, updatedAt: remoteTs);
        return base64Decode(b64.contains(',') ? b64.split(',').last : b64);
      }

      // сервер не новее — отдать кэш
      final cached = await load(u);
      if (cached != null) return cached;
      await save(u, b64, updatedAt: remoteTs);
      return base64Decode(b64.contains(',') ? b64.split(',').last : b64);
    } catch (_) {
      return await load(u);
    }
  }

  static Future<void> remove(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final u = username.toLowerCase().trim();
    await prefs.remove(keyFor(u));
    await prefs.remove(_tsKey(u));
  }
}