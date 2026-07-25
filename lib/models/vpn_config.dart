import 'package:uuid/uuid.dart';

enum VpnProtocol {
  wireguard,
  amneziawg,
  openvpn,
}

class VpnConfig {
  final String id;
  final String name;
  final VpnProtocol protocol;
  final String configData; // сам текст конфига
  final String? subscriptionUrl;
  final DateTime createdAt;

  VpnConfig({
    required this.id,
    required this.name,
    required this.protocol,
    required this.configData,
    this.subscriptionUrl,
    required this.createdAt,
  });

  factory VpnConfig.create({
    required String name,
    required VpnProtocol protocol,
    required String configData,
    String? subscriptionUrl,
  }) {
    return VpnConfig(
      id: const Uuid().v4(),
      name: name,
      protocol: protocol,
      configData: configData,
      subscriptionUrl: subscriptionUrl,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'protocol': protocol.name,
      'configData': configData,
      'subscriptionUrl': subscriptionUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    return VpnConfig(
      id: json['id'],
      name: json['name'],
      protocol: VpnProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => VpnProtocol.wireguard,
      ),
      configData: json['configData'],
      subscriptionUrl: json['subscriptionUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
