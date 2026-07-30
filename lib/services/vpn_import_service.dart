import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vpn_models.dart';
import 'vpn_storage_service.dart';
import 'vpn/vpn_log_service.dart';

class VpnImportResult {
  final List<VpnServer> servers;
  final String? suggestedSlotName;

  VpnImportResult(this.servers, {this.suggestedSlotName});
}

class VpnImportService {
  final _log = VpnLogService();

  List<VpnServer> parseRaw(String input) => parseRawFull(input).servers;

  VpnImportResult parseRawFull(String input) {
    final text = input.trim();
    if (text.isEmpty) return VpnImportResult([]);

    if (text.startsWith('[') || text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          final list = decoded
              .whereType<Map>()
              .map((m) => _fromMap(Map<String, dynamic>.from(m)))
              .whereType<VpnServer>()
              .toList();
          return VpnImportResult(list);
        }
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          // sing-box / clash-like
          if (map['outbounds'] is List) {
            final list = <VpnServer>[];
            for (final o in map['outbounds'] as List) {
              if (o is Map) {
                final s = _fromMap(Map<String, dynamic>.from(o));
                if (s != null) list.add(s);
              }
            }
            return VpnImportResult(list);
          }
          final s = _fromMap(map);
          return VpnImportResult(s != null ? [s] : []);
        }
      } catch (_) {}
    }

    final lines = text.split(RegExp(r'[\r\n]+'));
    final out = <VpnServer>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final s = _fromShareLink(t);
      if (s != null) out.add(s);
    }
    return VpnImportResult(out);
  }

  VpnServer? _fromShareLink(String link) {
    final lower = link.toLowerCase();
    VpnProtocol proto = VpnProtocol.unknown;

    if (lower.startsWith('vless://')) {
      proto = (lower.contains('xhttp') || lower.contains('type=xhttp'))
          ? VpnProtocol.vlessXhttp
          : VpnProtocol.vlessReality;
    } else if (lower.startsWith('hy2://') ||
        lower.startsWith('hysteria2://') ||
        lower.startsWith('hysteria://')) {
      proto = VpnProtocol.hysteria2;
    } else {
      return null;
    }

    String name = 'Server';
    final hash = link.indexOf('#');
    if (hash >= 0 && hash < link.length - 1) {
      try {
        name = Uri.decodeComponent(link.substring(hash + 1));
      } catch (_) {
        name = link.substring(hash + 1);
      }
    }
    if (name.isEmpty) name = 'Server';

    return VpnServer(
      id: 'srv_${DateTime.now().microsecondsSinceEpoch}_${_h(link)}',
      name: name,
      protocol: proto,
      rawConfig: link,
    );
  }

  VpnServer? _fromMap(Map<String, dynamic> m) {
    final type = (m['type'] ?? m['protocol'] ?? '').toString().toLowerCase();
    // skip non-proxy outbounds
    if (type == 'direct' || type == 'block' || type == 'dns' || type == 'selector') {
      return null;
    }

    final raw = m['raw']?.toString() ??
        m['link']?.toString() ??
        m['uri']?.toString() ??
        jsonEncode(m);

    final name = m['name']?.toString() ??
        m['tag']?.toString() ??
        m['ps']?.toString() ??
        m['remarks']?.toString() ??
        'Server';

    var proto = VpnProtocol.unknown;
    if (type.contains('hysteria')) {
      proto = VpnProtocol.hysteria2;
    } else if (type.contains('xhttp') ||
        (m['transport']?.toString().toLowerCase().contains('xhttp') ?? false)) {
      proto = VpnProtocol.vlessXhttp;
    } else if (type.contains('vless') ||
        type.contains('reality') ||
        m['tls']?['reality'] != null) {
      proto = VpnProtocol.vlessReality;
    } else if (raw.startsWith('vless://')) {
      proto = raw.toLowerCase().contains('xhttp')
          ? VpnProtocol.vlessXhttp
          : VpnProtocol.vlessReality;
    } else if (raw.startsWith('hy2://') || raw.startsWith('hysteria2://')) {
      proto = VpnProtocol.hysteria2;
    }

    if (proto == VpnProtocol.unknown && !raw.contains('://')) {
      // неизвестный без share-link — всё равно сохраняем raw для ядра
      proto = VpnProtocol.unknown;
    }

    return VpnServer(
      id: m['id']?.toString() ??
          'srv_${DateTime.now().microsecondsSinceEpoch}_${_h(raw)}',
      name: name,
      country: m['country']?.toString() ?? m['flag']?.toString(),
      provider: m['provider']?.toString() ?? m['isp']?.toString(),
      protocol: proto,
      rawConfig: raw,
    );
  }

  int _h(String s) => s.hashCode.abs() % 100000;

  Future<VpnImportResult> fetchSubscriptionFull(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) {
      _log.add('sub_http', 'HTTP ${res.statusCode}');
      throw Exception('HTTP ${res.statusCode}');
    }

    String? title;
    final cd = res.headers['content-disposition'];
    if (cd != null) {
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      if (m != null) title = m.group(1);
    }
    title ??= res.headers['profile-title'];
    if (title != null) {
      try {
        title = Uri.decodeComponent(title.replaceFirst('base64:', ''));
      } catch (_) {}
    }

    var body = res.body.trim();
    try {
      final decoded = utf8.decode(base64Decode(body.replaceAll(RegExp(r'\s'), '')));
      if (decoded.contains('://') || decoded.startsWith('[') || decoded.startsWith('{')) {
        body = decoded;
      }
    } catch (_) {}

    final parsed = parseRawFull(body);
    _log.add('sub_fetch', 'Серверов: ${parsed.servers.length}');
    return VpnImportResult(
      parsed.servers,
      suggestedSlotName: title ?? parsed.suggestedSlotName,
    );
  }

  Future<List<VpnServer>> fetchSubscription(String url) async {
    final r = await fetchSubscriptionFull(url);
    return r.servers;
  }

  List<VpnServer> limitServers(List<VpnServer> list) {
    if (list.length <= VpnStorageService.maxServersPerSub) return list;
    return list.take(VpnStorageService.maxServersPerSub).toList();
  }

  /// П.5 — валидация перед connect
  String? validateServer(VpnServer server) {
    if (server.rawConfig.trim().isEmpty) {
      return 'Пустой конфиг сервера';
    }
    if (server.protocol == VpnProtocol.unknown) {
      // не блокируем — ядро может понять raw; только предупреждение
      return null;
    }
    return null;
  }
}