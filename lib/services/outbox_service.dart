import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OutboxMessage {
  final String id;
  final String dialogId;
  final String from;
  final String to;
  final String text;
  final int timestamp;
  final int ttl;
  final String? image;
  final String? replyText;
  final String? replyUser;

  OutboxMessage({
    required this.id,
    required this.dialogId,
    required this.from,
    required this.to,
    required this.text,
    required this.timestamp,
    this.ttl = 0,
    this.image,
    this.replyText,
    this.replyUser,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dialogId': dialogId,
        'from': from,
        'to': to,
        'text': text,
        'timestamp': timestamp,
        'ttl': ttl,
        'image': image,
        'replyText': replyText,
        'replyUser': replyUser,
      };

  factory OutboxMessage.fromJson(Map<String, dynamic> json) {
    return OutboxMessage(
      id: json['id'] as String,
      dialogId: json['dialogId'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      text: (json['text'] ?? '') as String,
      timestamp: json['timestamp'] as int,
      ttl: (json['ttl'] ?? 0) as int,
      image: json['image'] as String?,
      replyText: json['replyText'] as String?,
      replyUser: json['replyUser'] as String?,
    );
  }
}

class OutboxService {
  static const _key = 'direct_outbox_v1';

  /// Стабильный id диалога для пары пользователей
  static String dialogIdFor(String a, String b) {
    final list = [a.toLowerCase(), b.toLowerCase()]..sort();
    return '${list[0]}_${list[1]}';
  }

  Future<List<OutboxMessage>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => OutboxMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _writeAll(List<OutboxMessage> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// Добавить сообщение в локальную очередь
  Future<OutboxMessage> add({
    required String from,
    required String to,
    required String text,
    int ttl = 0,
    String? image,
    String? replyText,
    String? replyUser,
  }) async {
    final all = await _readAll();
    final msg = OutboxMessage(
      id: 'ob_${DateTime.now().millisecondsSinceEpoch}',
      dialogId: dialogIdFor(from, to),
      from: from,
      to: to,
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl,
      image: image,
      replyText: replyText,
      replyUser: replyUser,
    );
    all.add(msg);
    await _writeAll(all);
    return msg;
  }

  /// Все исходящие pending для диалога (я = from)
  Future<List<OutboxMessage>> pendingForDialog({
    required String dialogId,
    required String myUsername,
  }) async {
    final all = await _readAll();
    return all
        .where((m) => m.dialogId == dialogId && m.from == myUsername)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Сколько сообщений ждёт от меня к toUser
  Future<int> countTo(String myUsername, String toUser) async {
    final all = await _readAll();
    final id = dialogIdFor(myUsername, toUser);
    return all.where((m) => m.dialogId == id && m.from == myUsername).length;
  }

  /// Удалить конкретные id после успешной доставки
  Future<void> removeByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final all = await _readAll();
    final set = ids.toSet();
    await _writeAll(all.where((m) => !set.contains(m.id)).toList());
  }

  /// Удалить весь outbox диалога от меня
  Future<void> clearDialog({
    required String dialogId,
    required String myUsername,
  }) async {
    final all = await _readAll();
    await _writeAll(
      all.where((m) => !(m.dialogId == dialogId && m.from == myUsername)).toList(),
    );
  }

  /// Все диалоги, где у меня есть исходящий pending
  Future<Set<String>> dialogIdsWithPending(String myUsername) async {
    final all = await _readAll();
    return all.where((m) => m.from == myUsername).map((m) => m.dialogId).toSet();
  }
}