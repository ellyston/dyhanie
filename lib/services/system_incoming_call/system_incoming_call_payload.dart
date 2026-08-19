/// Данные входящего вызова из push / native.
class SystemIncomingCallPayload {
  final String room;
  final String from;
  final String? to;
  final Map<String, dynamic>? offer; // SDP, если пришёл в push
  final int? ts;

  const SystemIncomingCallPayload({
    required this.room,
    required this.from,
    this.to,
    this.offer,
    this.ts,
  });

  factory SystemIncomingCallPayload.fromMap(Map<dynamic, dynamic> m) {
    Map<String, dynamic>? offer;
    final raw = m['offer'] ?? m['data'];
    if (raw is Map) {
      offer = Map<String, dynamic>.from(raw);
    }
    return SystemIncomingCallPayload(
      room: (m['room'] ?? '').toString(),
      from: (m['from'] ?? '').toString().toLowerCase().trim(),
      to: m['to']?.toString().toLowerCase().trim(),
      offer: offer,
      ts: m['ts'] is int ? m['ts'] as int : int.tryParse('${m['ts']}'),
    );
  }

  Map<String, dynamic> toMap() => {
        'room': room,
        'from': from,
        if (to != null) 'to': to,
        if (offer != null) 'offer': offer,
        if (ts != null) 'ts': ts,
      };

  bool get isValid => room.isNotEmpty && from.isNotEmpty;
}