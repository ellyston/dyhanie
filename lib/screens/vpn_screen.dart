import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/vpn_config.dart';
import '../services/vpn_storage_service.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  final VpnStorageService _storageService = VpnStorageService();
  List<VpnConfig> _configs = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String? _activeConfigId;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await _storageService.getAllConfigs();
    setState(() {
      _configs = configs;
      _isLoading = false;
    });
  }

  Future<void> _deleteConfig(String id) async {
    await _storageService.deleteConfig(id);
    if (_activeConfigId == id) {
      _activeConfigId = null;
      _isConnected = false;
    }
    await _loadConfigs();
  }

  void _showAddConfigDialog() {
    final nameController = TextEditingController();
    final configController = TextEditingController();
    VpnProtocol selectedProtocol = VpnProtocol.wireguard;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Новая конфигурация',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Название',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Протокол', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: VpnProtocol.values.map((protocol) {
                        final labels = {
                          VpnProtocol.wireguard: 'WireGuard',
                          VpnProtocol.amneziawg: 'AmneziaWG',
                          VpnProtocol.openvpn: 'OpenVPN',
                        };
                        final isSelected = selectedProtocol == protocol;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedProtocol = protocol),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.white38 : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  labels[protocol]!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: configController,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      maxLines: 7,
                      decoration: InputDecoration(
                        hintText: 'Вставь конфиг сюда...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty || configController.text.trim().isEmpty) return;

                          final newConfig = VpnConfig.create(
                            name: nameController.text.trim(),
                            protocol: selectedProtocol,
                            configData: configController.text.trim(),
                          );

                          await _storageService.saveConfig(newConfig);
                          Navigator.pop(context);
                          await _loadConfigs();
                        },
                        child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'ovpn', 'txt', 'json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final content = utf8.decode(file.bytes!);
      final name = file.name.replaceAll(RegExp(r'\.(conf|ovpn|txt|json)$'), '');

      VpnProtocol protocol = VpnProtocol.wireguard;
      if (content.contains('client') || content.contains('remote ')) {
        protocol = VpnProtocol.openvpn;
      }

      final newConfig = VpnConfig.create(
        name: name,
        protocol: protocol,
        configData: content,
      );

      await _storageService.saveConfig(newConfig);
      await _loadConfigs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Конфиг импортирован'),
            backgroundColor: Colors.white12,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  void _showAddSubscriptionDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Добавить подписку', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Название',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ссылка на подписку',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final url = urlController.text.trim();
                    if (name.isEmpty || url.isEmpty) return;

                    Navigator.pop(context);
                    await _importFromSubscription(name, url);
                  },
                  child: const Text('Добавить', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importFromSubscription(String name, String url) async {
    try {
      setState(() => _isLoading = true);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Ошибка загрузки');

      String content = response.body;
      try {
        content = utf8.decode(base64.decode(content.trim()));
      } catch (_) {}

      final newConfig = VpnConfig.create(
        name: name,
        protocol: VpnProtocol.wireguard,
        configData: content,
        subscriptionUrl: url,
      );

      await _storageService.saveConfig(newConfig);
      await _loadConfigs();
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'VPN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (value) {
              if (value == 'manual') _showAddConfigDialog();
              if (value == 'file') _importFromFile();
              if (value == 'subscription') _showAddSubscriptionDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'manual', child: Text('Вставить вручную', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'file', child: Text('Импорт из файла', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'subscription', child: Text('По ссылке', style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // Большой статус-блок
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isConnected
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isConnected
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                        child: Icon(
                          _isConnected ? Icons.shield : Icons.shield_outlined,
                          color: _isConnected ? Colors.greenAccent : Colors.white38,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isConnected ? 'Подключено' : 'Отключено',
                        style: TextStyle(
                          color: _isConnected ? Colors.greenAccent : Colors.white60,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected ? Colors.redAccent.withValues(alpha: 0.9) : Colors.white,
                            foregroundColor: _isConnected ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() => _isConnected = !_isConnected);
                            HapticFeedback.mediumImpact();
                          },
                          child: Text(
                            _isConnected ? 'Отключиться' : 'Подключиться',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Конфигурации',
                        style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      Text(
                        '${_configs.length}',
                        style: const TextStyle(color: Colors.white30, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _configs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_moon_outlined, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                              const SizedBox(height: 16),
                              const Text(
                                'Нет конфигураций',
                                style: TextStyle(color: Colors.white38, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Нажмите + чтобы добавить',
                                style: TextStyle(color: Colors.white24, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _configs.length,
                          itemBuilder: (context, index) {
                            final config = _configs[index];
                            final isActive = config.id == _activeConfigId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.transparent,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(
                                  config.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                subtitle: Text(
                                  config.protocol.name.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.3), size: 20),
                                  onPressed: () => _deleteConfig(config.id),
                                ),
                                onTap: () {
                                  setState(() => _activeConfigId = config.id);
                                  HapticFeedback.selectionClick();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
