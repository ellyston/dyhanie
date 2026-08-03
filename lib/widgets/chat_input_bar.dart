import 'package:flutter/material.dart';

import '../services/font_service.dart';
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
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyTo != null)
          Container(
            color: onSurf.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.reply, color: onSurf.withValues(alpha: 0.55), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${replyTo!['username']}: ${replyTo!['text']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontService.style(
                      fontSize: 13,
                      color: onSurf.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: onSurf.withValues(alpha: 0.4)),
                  onPressed: onClearReply,
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 8, 20),
          color: surface.withValues(alpha: 0.55),
          child: Row(
            children: [
              IconButton(
                onPressed: onAttach,
                icon: Icon(Icons.attach_file, color: onSurf.withValues(alpha: 0.75)),
              ),
              IconButton(
                onPressed: onEmoji,
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: onSurf.withValues(alpha: 0.75),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: FontService.style(color: onSurf),
                  decoration: InputDecoration(
                    hintText: p2pConnected
                        ? 'P2P...'
                        : (blockServerMessages
                            ? L.t('waiting_p2p')
                            : L.t('message_hint')),
                    hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton(
                onPressed: onSend,
                icon: Icon(Icons.send, color: onSurf),
              ),
            ],
          ),
        ),
      ],
    );
  }
}