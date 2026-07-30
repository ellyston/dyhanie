import 'dart:collection';

/// Только тех. события. Без IP, доменов, ключей, raw-конфигов.
class VpnLogService {
  static final VpnLogService _i = VpnLogService._();
  factory VpnLogService() => _i;
  VpnLogService._();

  static const maxEntries = 50;
  final _entries = Queue<VpnLogEntry>();

  List<VpnLogEntry> get entries => _entries.toList().reversed.toList();

  void add(String code, String message) {
    // жёстко режем подозрительное
    final safe = message
        .replaceAll(RegExp(r'https?://\S+'), '[url]')
        .replaceAll(RegExp(r'vless://\S+', caseSensitive: false), '[link]')
        .replaceAll(RegExp(r'hy2://\S+', caseSensitive: false), '[link]')
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '[ip]');

    _entries.addLast(VpnLogEntry(
      time: DateTime.now(),
      code: code,
      message: safe,
    ));
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  void clear() => _entries.clear();
}

class VpnLogEntry {
  final DateTime time;
  final String code;
  final String message;

  VpnLogEntry({
    required this.time,
    required this.code,
    required this.message,
  });

  String get timeLabel {
    final t = time;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}