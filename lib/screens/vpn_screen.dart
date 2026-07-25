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
    await _loadConfigs();
  }

  // ==================== ДОБАВЛЕНИЕ ВРУЧНУЮ ====================
  void _showAddConfigDialog() {
    final nameController = TextEditingController();
    final configController = TextEditingController();
    VpnProtocol selectedProtocol = VpnProtocol.wireguard;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Добавить конфигурацию', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Протокол', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: VpnProtocol.values.map((protocol) {
                        final labels = {
                          VpnProtocol.wireguard: 'WireGuard',
                          VpnProtocol.amneziawg: 'AmneziaWG',
                          VpnProtocol.openvpn: 'OpenVPN',
                        };
                        return ChoiceChip(
                          label: Text(labels[protocol]!),
                          selected: selectedProtocol == protocol,
                          selectedColor: Colors.white24,
                          labelStyle: TextStyle(
                            color: selectedProtocol == protocol ? Colors.white : Colors.white70,
                          ),
                          onSelected: (_) => setModalState(() => selectedProtocol = protocol),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: configController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Конфиг (текст)',
                        labelStyle: TextStyle(color: Colors.white54),
                        alignLabelWithHint: true,
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
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
                        child: const Text('Сохранить'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== ИМПОРТ ИЗ ФАЙЛА ====================
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'ovpn', 'txt', 'json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else {
        return;
      }

      final name = file.name.replaceAll(RegExp(r'\.(conf|ovpn|txt|json)$'), '');

      // Простое определение протокола
      VpnProtocol protocol = VpnProtocol.wireguard;
      if (content.contains('[Interface]') && content.contains('PrivateKey')) {
        protocol = VpnProtocol.wireguard;
      } else if (content.contains('client') || content.contains('remote ')) {
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
          const SnackBar(content: Text('Конфиг успешно импортирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка импорта: $e')),
        );
      }
    }
  }

  // ==================== ДОБАВЛЕНИЕ ПО ПОДПИСКЕ ====================
  void _showAddSubscriptionDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Добавить подписку', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Название',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Ссылка на подписку',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final url = urlController.text.trim();
                    if (name.isEmpty || url.isEmpty) return;

                    Navigator.pop(context);
                    await _importFromSubscription(name, url);
                  },
                  child: const Text('Добавить'),
                ),
              ),
              const SizedBox(height: 20),
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
      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить подписку');
      }

      String content = response.body;

      // Пробуем декодировать base64 (часто подписки в base64)
      try {
        content = utf8.decode(base64.decode(content.trim()));
      } catch (_) {}

      final newConfig = VpnConfig.create(
        name: name,
        protocol: VpnProtocol.wireguard, // по умолчанию, можно доработать определение
        configData: content,
        subscriptionUrl: url,
      );

      await _storageService.saveConfig(newConfig);
      await _loadConfigs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Подписка успешно добавлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
        title: const Text('VPN', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Colors.white),
            color: const Color(0xFF1A1A1A),
            onSelected: (value) {
              if (value == 'manual') _showAddConfigDialog();
              if (value == 'file') _importFromFile();
              if (value == 'subscription') _showAddSubscriptionDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'manual', child: Text('Вставить вручную', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'file', child: Text('Импорт из файла', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'subscription', child: Text('По ссылке (подписка)', style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // Статус
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green.withValues(alpha: 0.15) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isConnected ? Icons.shield : Icons.shield_outlined,
                        color: _isConnected ? Colors.green : Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isConnected ? 'Подключено' : 'Отключено',
                        style: TextStyle(
                          color: _isConnected ? Colors.green : Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected ? Colors.redAccent : Colors.white,
                            foregroundColor: _isConnected ? Colors.white : Colors.black,
                          ),
                          onPressed: () {
                            setState(() => _isConnected = !_isConnected);
                            HapticFeedback.mediumImpact();
                          },
                          child: Text(_isConnected ? 'Отключиться' : 'Подключиться'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Сохранённые конфигурации', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _configs.isEmpty
                      ? const Center(
                          child: Text(
                            'Нет сохранённых конфигураций\nНажмите +, чтобы добавить',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _configs.length,
                          itemBuilder: (context, index) {
                            final config = _configs[index];
                            final isActive = config.id == _activeConfigId;

                            return Card(
                              color: Colors.white.withValues(alpha: 0.07),
                              child: ListTile(
                                title: Text(config.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  config.protocol.name.toUpperCase(),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                  onPressed: () => _deleteConfig(config.id),
                                ),
                                onTap: () => setState(() => _activeConfigId = config.id),
                                selected: isActive,
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
