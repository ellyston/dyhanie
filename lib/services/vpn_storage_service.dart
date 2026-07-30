import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vpn_models.dart';

class VpnStorageService {
  static const _keySlots = 'vpn_slots_v1';
  static const _keyActiveSlot = 'vpn_active_slot_v1';
  static const _keyActiveServer = 'vpn_active_server_v1';
  static const maxSlots = 5;
  static const maxServersPerSub = 15;

  Future<List<VpnSlot>> loadSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySlots);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VpnSlot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSlots(List<VpnSlot> slots) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySlots,
      jsonEncode(slots.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> setActiveIds(String? slotId, String? serverId) async {
    final prefs = await SharedPreferences.getInstance();
    if (slotId == null) {
      await prefs.remove(_keyActiveSlot);
    } else {
      await prefs.setString(_keyActiveSlot, slotId);
    }
    if (serverId == null) {
      await prefs.remove(_keyActiveServer);
    } else {
      await prefs.setString(_keyActiveServer, serverId);
    }
  }

  Future<(String?, String?)> getActiveIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyActiveSlot), prefs.getString(_keyActiveServer));
  }
}