import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/registry.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart';

/// The activity view's summary: one or two daily insight cards, picked from
/// the applicable card types in `registry.dart`. Replaces the old heatmap +
/// treemap summary.
class InsightsSection extends StatefulWidget {
  const InsightsSection({super.key});

  @override
  State<InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends State<InsightsSection> {
  late final Future<(InsightContext, List<InsightSelection<dynamic>>)> _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      final insightContext = await InsightContext.load();
      return (insightContext, await selectInsightCards(insightContext));
    }();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder<(InsightContext, List<InsightSelection<dynamic>>)>(
      future: _future,
      loading: (context) => const DionProgressBar().paddingVertical(24),
      // A failed summary must not take the activity feed with it.
      error: (context, error, stackTrace) {
        logger.e(
          'Failed to build insight cards',
          error: error,
          stackTrace: stackTrace,
        );
        return const SizedBox.shrink();
      },
      builder: (context, data) {
        final (_, selections) = data;
        if (selections.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final twoColumns = constraints.maxWidth >= 620;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final selection in selections)
                    _CardChrome(
                      card: selection.card,
                      width: cardWidth,
                      child: selection.card.build(context, selection.data),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Uniform card frame: fixed height, small uppercase header row, then the
/// card's own graphic.
class _CardChrome extends StatelessWidget {
  final InsightCard<dynamic> card;
  final double width;
  final Widget child;

  const _CardChrome({
    required this.card,
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 150,
      child: DionContainer(
        color: context.theme.colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    card.icon,
                    size: 13,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    card.label.toUpperCase(),
                    style: DionTypography.sectionHeader(
                      context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
