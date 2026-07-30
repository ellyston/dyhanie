import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showSearch;
  final TextEditingController searchController;
  final bool isDirect;
  final String roomCode;
  final String? otherUser;
  final bool otherOnline;
  final String connectionMode;
  final bool blockServerMessages;
  final bool wipeOnExit;

  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleServerBlock;
  final VoidCallback onCall;
  final VoidCallback onTimer;
  final VoidCallback onToggleWipe;
  final VoidCallback onSettings;

  const ChatAppBar({
    super.key,
    required this.showSearch,
    required this.searchController,
    required this.isDirect,
    required this.roomCode,
    required this.otherUser,
    required this.otherOnline,
    required this.connectionMode,
    required this.blockServerMessages,
    required this.wipeOnExit,
    required this.onBack,
    required this.onToggleSearch,
    required this.onSearchChanged,
    required this.onToggleServerBlock,
    required this.onCall,
    required this.onTimer,
    required this.onToggleWipe,
    required this.onSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      title: showSearch
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Поиск...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onChanged: onSearchChanged,
            )
          : Column(
              children: [
                Text(
                  isDirect ? 'Диалог' : 'Дыхание',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  otherUser != null
                      ? '@$otherUser • ${otherOnline ? "онлайн" : "оффлайн"} • $connectionMode'
                      : (isDirect
                          ? 'Ожидание собеседника'
                          : 'Код: $roomCode'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            showSearch ? Icons.close : Icons.search,
            color: Colors.white70,
          ),
          onPressed: onToggleSearch,
        ),
        IconButton(
          icon: Icon(
            blockServerMessages ? Icons.cloud_off : Icons.cloud_queue,
            color: blockServerMessages ? Colors.redAccent : Colors.white70,
          ),
          onPressed: onToggleServerBlock,
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white70),
          onPressed: onCall,
        ),
        IconButton(
          icon: const Icon(Icons.timer, color: Colors.white70),
          onPressed: onTimer,
        ),
        IconButton(
          tooltip: wipeOnExit
              ? 'При выходе удалить всё'
              : 'При выходе сохранить диалог',
          icon: Icon(
            wipeOnExit ? Icons.delete_forever : Icons.save_outlined,
            color: wipeOnExit ? Colors.redAccent : Colors.greenAccent,
          ),
          onPressed: onToggleWipe,
        ),
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.white70),
          onPressed: onSettings,
        ),
      ],
    );
  }
}