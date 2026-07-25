import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    const Text(
                      'Добавить конфигурацию',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
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
                          onSelected: (_) {
                            setModalState(() => selectedProtocol = protocol);
                          },
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
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty ||
                              configController.text.trim().isEmpty) {
                            return;
                          }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('VPN', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddConfigDialog,
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
                            // Пока просто переключаем статус (позже подключим реальный VPN)
                            setState(() {
                              _isConnected = !_isConnected;
                            });
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
                    child: Text(
                      'Сохранённые конфигурации',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
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
                                title: Text(
                                  config.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  config.protocol.name.toUpperCase(),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                                  onPressed: () => _deleteConfig(config.id),
                                ),
                                onTap: () {
                                  setState(() {
                                    _activeConfigId = config.id;
                                  });
                                },
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
