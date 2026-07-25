import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/vpn_config.dart';

class VpnStorageService {
  static const _storageKey = 'vpn_configs';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<VpnConfig>> getAllConfigs() async {
    final data = await _storage.read(key: _storageKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => VpnConfig.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveConfig(VpnConfig config) async {
    final configs = await getAllConfigs();
    configs.add(config);
    await _saveAll(configs);
  }

  Future<void> updateConfig(VpnConfig config) async {
    final configs = await getAllConfigs();
    final index = configs.indexWhere((e) => e.id == config.id);
    if (index != -1) {
      configs[index] = config;
      await _saveAll(configs);
    }
  }

  Future<void> deleteConfig(String id) async {
    final configs = await getAllConfigs();
    configs.removeWhere((e) => e.id == id);
    await _saveAll(configs);
  }

  Future<void> _saveAll(List<VpnConfig> configs) async {
    final jsonList = configs.map((e) => e.toJson()).toList();
    await _storage.write(key: _storageKey, value: jsonEncode(jsonList));
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _storageKey);
  }
}
