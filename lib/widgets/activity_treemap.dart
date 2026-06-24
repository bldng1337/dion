import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/entry_duration.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_treemap/flutter_treemap.dart';
import 'package:go_router/go_router.dart';

class ActivityTreemap extends StatelessWidget {
  final List<EntryDuration> entries;

  const ActivityTreemap({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No activity yet',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final nodes = entries
        .map(
          (e) => Treemap(
            value: e.duration.inSeconds.toDouble(),
            label: e.entry.title,
            color: context.theme.colorScheme.surfaceContainerHighest,
          ),
        )
        .toList();

    return FlutterTreemap(
      nodes: nodes,
      // The default tile content is unused; we render everything in
      // [tileWrapper] where we get the exact tile rect.
      tileBuilder: (_, _, _, _) => const SizedBox.shrink(),
      border: Border.all(color: context.theme.colorScheme.surface, width: 2),
      tileWrapper: (context, child, node, index, rect) {
        final entry = entries[index].entry;
        final duration = entries[index].duration;
        return GestureDetector(
          onTap: () => context.push('/detail', extra: [entry]),
          child: _EntryTile(entry: entry, duration: duration, rect: rect),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final Entry entry;
  final Duration duration;
  final Rect rect;

  const _EntryTile({
    required this.entry,
    required this.duration,
    required this.rect,
  });

  @override
  Widget build(BuildContext context) {
    final showLabel = rect.width > 64 && rect.height > 40;
    final showDuration = rect.width > 96 && rect.height > 56;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover background
          DionImage.fromLink(
            link: entry.cover,
            boxFit: BoxFit.cover,
            errorWidget: _CoverFallback(entry: entry),
            loadingBuilder: (context) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          // Readability scrim
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
          // Label + duration
          if (showLabel)
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.trim(),
                    maxLines: showDuration ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
                  if (showDuration) ...[
                    const SizedBox(height: 1),
                    Text(
                      duration.formatrelative(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final Entry entry;

  const _CoverFallback({required this.entry});

  @override
  Widget build(BuildContext context) {
    final initial = entry.title.trim().isNotEmpty
        ? entry.title.trim().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      color: context.theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                initial,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                entry.mediaType.icon,
                size: 18,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityTreemapPanel extends StatelessWidget {
  final List<EntryDuration> entries;

  const ActivityTreemapPanel({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return DionContainer(
      color: context.theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Entries',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: ActivityTreemap(entries: entries)),
          ],
        ),
      ),
    );
  }
}
