import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'dyhanie_api.dart';

class AvatarCache {
  static String keyFor(String username) =>
      'avatar_${username.toLowerCase().trim()}';

  static Future<void> save(String username, String base64Data) async {
    final clean = base64Data.contains(',')
        ? base64Data.split(',').last.trim()
        : base64Data.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFor(username), clean);
  }

  static Future<void> saveBytes(String username, Uint8List bytes) async {
    await save(username, base64Encode(bytes));
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

  /// Кэш → если пусто, сервер → снова кэш
  static Future<Uint8List?> fetch(
    String username, {
    bool forceNetwork = false,
  }) async {
    final u = username.toLowerCase().trim();
    if (u.isEmpty) return null;

    if (!forceNetwork) {
      final cached = await load(u);
      if (cached != null) return cached;
    }

    try {
      final b64 = await DyhanieApi.instance.avatarGet(u);
      if (b64 == null || b64.isEmpty) return null;
      await save(u, b64);
      return base64Decode(b64.contains(',') ? b64.split(',').last : b64);
    } catch (_) {
      return await load(u);
    }
  }

  static Future<void> remove(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(username));
  }
}