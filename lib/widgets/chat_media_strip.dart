import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MediaStripMode { voice, video }

/// Над полем ввода: tap = голос↔видео, hold = запись (только голос).
/// Видео — tap в режиме «Видео» (без удержания таймера 20 с).
class ChatMediaStrip extends StatefulWidget {
  final void Function(MediaStripMode mode) onRecordStart;
  final void Function(MediaStripMode mode) onRecordEnd;
  final void Function(MediaStripMode mode) onRecordCancel;

  const ChatMediaStrip({
    super.key,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
  });

  @override
  State<ChatMediaStrip> createState() => _ChatMediaStripState();
}

class _ChatMediaStripState extends State<ChatMediaStrip> {
  MediaStripMode _mode = MediaStripMode.voice;
  bool _recording = false;
  DateTime? _started;
  Timer? _tick;
  int _elapsedMs = 0;

  static const _maxVoiceMs = 60 * 1000;

  void _toggleMode() {
    if (_recording) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = _mode == MediaStripMode.voice
          ? MediaStripMode.video
          : MediaStripMode.voice;
    });
  }

  /// Голос — зажатие; видео — одно нажатие (без полоски 0…20 с).
  void _onTap() {
    if (_recording) return;
    if (_mode == MediaStripMode.video) {
      HapticFeedback.mediumImpact();
      widget.onRecordStart(MediaStripMode.video);
      return;
    }
    _toggleMode();
  }

  void _start(LongPressStartDetails _) {
    if (_mode == MediaStripMode.video) {
      // видео не через hold — иначе таймер «залипает» на 20 с
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _started = DateTime.now();
      _elapsedMs = 0;
    });
    widget.onRecordStart(MediaStripMode.voice);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_recording || _started == null) return;
      final ms = DateTime.now().difference(_started!).inMilliseconds;
      if (!mounted) return;
      setState(() => _elapsedMs = ms);
      if (ms >= _maxVoiceMs) _stop(send: true);
    });
  }

  void _end(LongPressEndDetails _) {
    if (_mode == MediaStripMode.video) return;
    _stop(send: true);
  }

  void _stop({required bool send}) {
    if (!_recording) return;
    _tick?.cancel();
    _tick = null;
    if (mounted) setState(() => _recording = false);
    _started = null;
    _elapsedMs = 0;
    if (send) {
      widget.onRecordEnd(MediaStripMode.voice);
    } else {
      widget.onRecordCancel(MediaStripMode.voice);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final sec = (_elapsedMs / 1000).floor();

    final String label;
    if (_recording) {
      label = 'Голос · $sec / 60 с';
    } else if (_mode == MediaStripMode.voice) {
      label = 'Голос';
    } else {
      label = 'Видео';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: GestureDetector(
        onTap: _onTap,
        onLongPressStart: _start,
        onLongPressEnd: _end,
        onLongPressCancel: () {
          if (_recording) _stop(send: false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _recording
                ? Colors.redAccent.withValues(alpha: 0.28)
                : onSurf.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _mode == MediaStripMode.video
                  ? onSurf.withValues(alpha: 0.4)
                  : onSurf.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: onSurf.withValues(alpha: _recording ? 0.95 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}