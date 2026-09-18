import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart' show ChapterKind;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/view/chapters/chapter_controller.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class SeekbarGeometry {
  final EdgeInsets seekBarMargin;
  final double seekBarHeight;
  final EdgeInsets buttonBarMargin;
  final double buttonBarHeight;

  const SeekbarGeometry({
    required this.seekBarMargin,
    required this.seekBarHeight,
    required this.buttonBarMargin,
    required this.buttonBarHeight,
  });
}

class ChapterSeekbarOverlay extends StatelessWidget {
  final ChapterController controller;
  final SeekbarGeometry geometry;
  final Widget? trailing;

  const ChapterSeekbarOverlay({
    super.key,
    required this.controller,
    required this.geometry,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // The row overlaps the seek bar's touch container; without
          // IgnorePointer this layer would steal taps meant for the seek bar.
          IgnorePointer(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final chapter = controller.currentChapter;
                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    if (controller.hasChapters)
                      CustomPaint(
                        painter: _ChapterMarkerPainter(
                          chapters: controller.chapters,
                          duration: controller.player.state.duration,
                          geometry: geometry,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PositionDurationLabel(player: controller.player),
                          if (chapter != null)
                            _OverlayText(
                              chapter.title,
                              fontSize: 11,
                            ).paddingOnly(top: 2),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

class _PositionDurationLabel extends StatelessWidget {
  final Player player;

  const _PositionDurationLabel({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? player.state.position;
            final duration = durationSnapshot.data ?? player.state.duration;
            return _OverlayText(
              '${_formatClock(position)} / ${_formatClock(duration)}',
            );
          },
        );
      },
    );
  }
}

class _OverlayText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _OverlayText(this.text, {this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
      ),
    );
  }
}

String _formatClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _ChapterMarkerPainter extends CustomPainter {
  final List<PlaybackChapter> chapters;
  final Duration duration;
  final SeekbarGeometry geometry;

  _ChapterMarkerPainter({
    required this.chapters,
    required this.duration,
    required this.geometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= Duration.zero) return;
    final g = geometry;
    // The overlay widget spans the button bar row; the seek bar sits above
    // it, inset by the difference of the two margins.
    final leftInset = g.seekBarMargin.left - g.buttonBarMargin.left;
    final rightInset = g.seekBarMargin.right - g.buttonBarMargin.right;
    if (leftInset < 0 ||
        rightInset < 0 ||
        leftInset + rightInset >= size.width) {
      return;
    }
    final barWidth = size.width - leftInset - rightInset;
    // Vertical positions measured upward from the controls' bottom edge,
    // then converted into the overlay widget's top-down coordinates.
    final markerTopFromBottom = g.buttonBarMargin.bottom + g.buttonBarHeight;
    final barCenterY =
        markerTopFromBottom - g.seekBarMargin.bottom - g.seekBarHeight / 2;

    final paint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.6);
    for (final chapter in chapters) {
      final x =
          leftInset +
          (chapter.start.inMilliseconds / duration.inMilliseconds) * barWidth;
      final rect = Rect.fromCenter(
        center: Offset(x, barCenterY),
        width: 2.5,
        height: 9,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(const Offset(0.5, 0.5)),
          const Radius.circular(1),
        ),
        shadow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ChapterMarkerPainter oldDelegate) =>
      oldDelegate.chapters != chapters ||
      oldDelegate.duration != duration ||
      oldDelegate.geometry != geometry;
}

class ChapterSkipButton extends StatelessWidget {
  final ChapterController controller;
  final Color? color;

  const ChapterSkipButton({super.key, required this.controller, this.color});

  static const _kindLabels = {
    ChapterKind.intro: 'Intro',
    ChapterKind.outro: 'Outro',
    ChapterKind.recap: 'Recap',
    ChapterKind.filler: 'Filler',
    ChapterKind.preview: 'Preview',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final kind = controller.currentChapter?.kind;
        final visible = controller.canSkipCurrent && kind != null;
        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: DionDuration.normal,
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !visible,
            child: Material(
              color: color ?? Colors.black.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.all(
                Radius.circular(DionRadius.sm),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.all(
                  Radius.circular(DionRadius.sm),
                ),
                onTap: controller.skipCurrent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DionSpacing.md,
                    vertical: DionSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip ${_kindLabels[kind]}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      4.widthBox,
                      const Icon(
                        Icons.skip_next,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
