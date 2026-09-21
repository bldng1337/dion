import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:dionysos/views/view/chapters/chapter_controller.dart';
import 'package:flutter/material.dart';

class ChapterProgressBar extends StatelessWidget {
  final ChapterController controller;
  final Duration progress;
  final Duration total;
  final Duration buffered;
  final void Function(Duration) onSeek;

  const ChapterProgressBar({
    super.key,
    required this.controller,
    required this.progress,
    required this.total,
    required this.buffered,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware so the ticks stay visible on the light track in light mode.
    final tickColor = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.9);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ProgressBar(
              progress: progress,
              total: total,
              buffered: buffered,
              onSeek: onSeek,
            ),
            if (controller.hasChapters && total > Duration.zero)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ChapterTickPainter(
                      chapters: controller.chapters,
                      total: total,
                      tickColor: tickColor,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChapterTickPainter extends CustomPainter {
  final List<PlaybackChapter> chapters;
  final Duration total;
  final Color tickColor;

  _ChapterTickPainter({
    required this.chapters,
    required this.total,
    required this.tickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The package draws the bar centered inside an area as tall as the thumb
    // diameter (max(2 * thumbRadius, barHeight) with defaults 10/5 => 20),
    // and insets it horizontally by barHeight / 2 for the round cap.
    // Mirroring that here keeps the ticks on the track.
    const barAreaHeight = 20.0;
    const barHeight = 5.0;
    const barCenterY = barAreaHeight / 2;
    final paint = Paint()..color = tickColor;
    for (final chapter in chapters) {
      if (chapter.start > total) continue;
      final fraction = chapter.start.inMilliseconds / total.inMilliseconds;
      final x = (fraction * (size.width - barHeight) + barHeight / 2).clamp(
        10.0,
        size.width - 10.0,
      );
      final rect = Rect.fromCenter(
        center: Offset(x, barCenterY),
        width: 2.5,
        height: 11,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChapterTickPainter oldDelegate) =>
      oldDelegate.chapters != chapters ||
      oldDelegate.total != total ||
      oldDelegate.tickColor != tickColor;
}
