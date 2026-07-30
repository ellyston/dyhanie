import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/locale_service.dart';

class ChatMessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final String myUsername;
  final double fontSize;
  final bool isSavedChat;
  final int selectedTime;
  final Map<String, int> remaining;
  final int? otherLastRead;
  final ScrollController scrollController;
  final void Function(Map<String, dynamic> msg) onLongPress;
  final void Function(String key) onSwipeDelete;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.myUsername,
    required this.fontSize,
    required this.isSavedChat,
    required this.selectedTime,
    required this.remaining,
    required this.otherLastRead,
    required this.scrollController,
    required this.onLongPress,
    required this.onSwipeDelete,
  });

  String _fmtTime(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusIcon(Map msg) {
    if (msg['username'] != myUsername) return const SizedBox.shrink();
    final ts = msg['timestamp'] as int? ?? 0;
    final read = otherLastRead != null && otherLastRead! >= ts;
    return Icon(
      read ? Icons.done_all : Icons.done,
      size: 14,
      color: read ? Colors.lightBlueAccent : Colors.white38,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        child: Text(L.t('quiet_chat'), style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final key = msg['key'] as String;
        final isMe = msg['username'] == myUsername;
        final rem = remaining[key];
        final text = msg['text']?.toString() ?? '';
        final isP2P = msg['p2p'] == true;
        final img = msg['image']?.toString();
        final ts = msg['timestamp'] as int? ?? 0;

        Widget bubble = Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => onLongPress(msg),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      '@${msg['username']}',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: fontSize - 3,
                      ),
                    ),
                  if (msg['replyText'] != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: Colors.white38, width: 2),
                        ),
                      ),
                      child: Text(
                        '${msg['replyUser']}: ${msg['replyText']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  if (img != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(img),
                          fit: BoxFit.cover,
                          width: 200,
                          errorBuilder: (_, __, ___) =>
                              const Text('🖼', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(color: Colors.white, fontSize: fontSize),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isP2P ? L.t('p2p_connected') : L.t('via_server'),
                        style: TextStyle(
                          color: isP2P
                              ? Colors.greenAccent.withValues(alpha: 0.8)
                              : Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        ' · ${_fmtTime(ts)}',
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                      if (rem != null && !isSavedChat && selectedTime > 0)
                        Text(
                          ' · ${rem}s',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      if (((msg['ttl'] as int?) ?? 0) == 0)
                        const Text(
                          ' · ∞',
                          style: TextStyle(color: Colors.white30, fontSize: 10),
                        ),
                      const SizedBox(width: 4),
                      _statusIcon(msg),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        if (isMe) {
          return Dismissible(
            key: Key(key),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => onSwipeDelete(key),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
            child: bubble,
          );
        }
        return bubble;
      },
    );
  }
}