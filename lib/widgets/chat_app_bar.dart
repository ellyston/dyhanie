import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/font_service.dart';
import '../services/locale_service.dart';

class ChatAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool showSearch;
  final TextEditingController searchController;
  final bool isDirect;
  final String roomCode;
  final String? otherUser;
  final bool otherOnline;
  final String connectionMode;
  final bool blockServerMessages;
  final bool wipeOnExit;
  final String myUsername;
  final Uint8List? myAvatarBytes;
  final Uint8List? otherAvatarBytes;

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
    required this.myUsername,
    required this.myAvatarBytes,
    required this.otherAvatarBytes,
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
  Size get preferredSize => const Size.fromHeight(96);

  @override
  State<ChatAppBar> createState() => _ChatAppBarState();
}

class _ChatAppBarState extends State<ChatAppBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _air;

  @override
  void initState() {
    super.initState();
    _air = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _air.dispose();
    super.dispose();
  }

  Widget _avatar(Uint8List? bytes, String? name, {bool highlight = false}) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final letter =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight
              ? Colors.greenAccent.withValues(alpha: 0.7)
              : onSurf.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: bytes != null && bytes.isNotEmpty
            ? Image.memory(bytes, fit: BoxFit.cover)
            : Container(
                color: onSurf.withValues(alpha: 0.1),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: FontService.style(fontSize: 14, color: onSurf),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;

    return AppBar(
      backgroundColor: surface.withValues(alpha: 0.55),
      foregroundColor: onSurf,
      toolbarHeight: 96,
      leadingWidth: 48,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: onSurf),
        onPressed: widget.onBack,
      ),
      title: widget.showSearch
          ? TextField(
              controller: widget.searchController,
              autofocus: true,
              style: FontService.style(color: onSurf),
              decoration: InputDecoration(
                hintText: L.t('search'),
                hintStyle: TextStyle(color: onSurf.withValues(alpha: 0.4)),
                border: InputBorder.none,
              ),
              onChanged: widget.onSearchChanged,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      _avatar(widget.myAvatarBytes, widget.myUsername),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _air,
                          builder: (_, __) {
                            return CustomPaint(
                              painter: _BreathAirPainter(
                                progress: _air.value,
                                color: onSurf,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                      _avatar(
                        widget.otherAvatarBytes,
                        widget.otherUser,
                        highlight: widget.otherOnline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isDirect ? L.t('dialog') : L.t('app_name'),
                  style: FontService.style(fontSize: 15, color: onSurf),
                ),
                Text(
                  widget.otherUser != null
                      ? '@${widget.otherUser} · ${widget.otherOnline ? L.t('online') : L.t('offline')} · ${widget.connectionMode}'
                      : (widget.isDirect
                          ? L.t('waiting_peer')
                          : '${L.t('room_code')}: ${widget.roomCode}'),
                  style: FontService.style(
                    fontSize: 11,
                    color: onSurf.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            widget.showSearch ? Icons.close : Icons.search,
            color: onSurf.withValues(alpha: 0.75),
          ),
          onPressed: widget.onToggleSearch,
        ),
        IconButton(
          icon: Icon(
            widget.blockServerMessages ? Icons.cloud_off : Icons.cloud_queue,
            color: widget.blockServerMessages
                ? Colors.redAccent
                : onSurf.withValues(alpha: 0.75),
          ),
          onPressed: widget.onToggleServerBlock,
        ),
        IconButton(
          icon: Icon(Icons.call, color: onSurf.withValues(alpha: 0.75)),
          onPressed: widget.onCall,
        ),
        IconButton(
          icon: Icon(Icons.timer, color: onSurf.withValues(alpha: 0.75)),
          onPressed: widget.onTimer,
        ),
        IconButton(
          tooltip:
              widget.wipeOnExit ? L.t('wipe_on_exit') : L.t('keep_on_exit'),
          icon: Icon(
            widget.wipeOnExit ? Icons.delete_forever : Icons.save_outlined,
            color:
                widget.wipeOnExit ? Colors.redAccent : Colors.greenAccent,
          ),
          onPressed: widget.onToggleWipe,
        ),
        IconButton(
          icon: Icon(Icons.tune, color: onSurf.withValues(alpha: 0.75)),
          onPressed: widget.onSettings,
        ),
      ],
    );
  }
}

class _BreathAirPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BreathAirPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final phase = (progress + i * 0.22) % 1.0;
      final alpha = (math.sin(phase * math.pi) * 0.45).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha);

      final path = Path();
      final amp = 3.0 + i * 1.5;
      path.moveTo(4, midY);
      for (double x = 4; x <= size.width - 4; x += 3) {
        final t = x / size.width;
        final y = midY +
            math.sin((t * 4 + phase * 2) * math.pi) *
                amp *
                math.sin(phase * math.pi);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreathAirPainter old) =>
      old.progress != progress || old.color != color;
}