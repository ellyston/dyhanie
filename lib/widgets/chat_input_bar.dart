import 'package:flutter/material.dart';

import '../services/locale_service.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool p2pConnected;
  final bool blockServerMessages;
  final Map<String, dynamic>? replyTo;
  final VoidCallback onAttach;
  final VoidCallback onEmoji;
  final VoidCallback onSend;
  final VoidCallback onClearReply;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.p2pConnected,
    required this.blockServerMessages,
    required this.replyTo,
    required this.onAttach,
    required this.onEmoji,
    required this.onSend,
    required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTo != null)
          Container(
            color: Colors.white10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.reply, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${replyTo!['username']}: ${replyTo!['text']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, size: 16, color: Colors.white38),
                  onPressed: onClearReply,
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 8, 20),
          color: Colors.black54,
          child: Row(
            children: [
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file, color: Colors.white70),
              ),
              IconButton(
                onPressed: onEmoji,
                icon: const Icon(
                  Icons.emoji_emotions_outlined,
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: p2pConnected
                        ? 'P2P...'
                        : (blockServerMessages
                            ? L.t('waiting_p2p')
                            : L.t('message_hint')),
                    hintStyle: const TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton(
                onPressed: onSend,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}