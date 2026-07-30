import 'package:flutter_test/flutter_test.dart';
import 'package:dyhanie/services/vpn_import_service.dart';
import 'package:dyhanie/models/vpn_models.dart';

void main() {
  final import = VpnImportService();

  test('parse vless link', () {
    final r = import.parseRawFull(
      'vless://uuid@example.com:443?security=reality&type=tcp#NL-1',
    );
    expect(r.servers.length, 1);
    expect(r.servers.first.protocol, VpnProtocol.vlessReality);
    expect(r.servers.first.name, 'NL-1');
  });

  test('parse hy2 link', () {
    final r = import.parseRawFull('hy2://secret@host:443#Hy2-Node');
    expect(r.servers.length, 1);
    expect(r.servers.first.protocol, VpnProtocol.hysteria2);
  });

  test('empty', () {
    expect(import.parseRaw('').isEmpty, true);
  });
}