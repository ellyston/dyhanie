import 'package:flutter/material.dart';

/// Квадрат со скруглёнными углами (превью; play — следующим шагом).
class VideoMessageBubble extends StatelessWidget {
  final String base64Data;
  final double size;

  const VideoMessageBubble({
    super.key,
    required this.base64Data,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final s = size.clamp(56.0, 200.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(s * 0.18),
      child: Container(
        width: s,
        height: s,
        color: onSurf.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Icon(
          Icons.play_circle_fill,
          size: s * 0.42,
          color: onSurf.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}