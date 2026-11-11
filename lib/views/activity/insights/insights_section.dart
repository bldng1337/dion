import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/registry.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart';

const _cardGap = DionSpacing.md;
const _minCardWidth = 280.0;
const _maxColumns = 3;
const _baseCardHeight = 152.0;

/// Card height for the ambient text scale. Card content is mostly text, so
/// the frame grows with it rather than squeezing everything inside.
double insightCardHeight(TextScaler scaler) =>
    _baseCardHeight * (scaler.scale(14) / 14).clamp(1.0, 1.6);

/// Columns that fit [width] without a card dropping below its minimum width.
int insightColumnsFor(double width) =>
    ((width + _cardGap) / (_minCardWidth + _cardGap)).floor().clamp(
      1,
      _maxColumns,
    );

/// The activity view's summary: a row of daily insight cards, picked from
/// the applicable card types in `registry.dart`. Phones stack two cards;
/// wider windows show one card per column.
class InsightsSection extends StatefulWidget {
  const InsightsSection({super.key});

  @override
  State<InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends State<InsightsSection> {
  late final Future<List<InsightSelection<dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      final insightContext = await InsightContext.load();
      return selectInsightCards(insightContext);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder<List<InsightSelection<dynamic>>>(
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
      builder: (context, selections) {
        if (selections.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            DionSpacing.lg,
            DionSpacing.lg,
            DionSpacing.lg,
            DionSpacing.xs,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => InsightGrid(
              selections: selections,
              width: constraints.maxWidth,
            ),
          ),
        );
      },
    );
  }
}

/// Lays the first fitting [selections] out in equal-width rows. A card whose
/// build throws is logged and replaced by the next selection.
class InsightGrid extends StatelessWidget {
  final List<InsightSelection<dynamic>> selections;
  final double width;

  const InsightGrid({super.key, required this.selections, required this.width});

  @override
  Widget build(BuildContext context) {
    final columns = insightColumnsFor(width);
    final wanted = columns == 1 ? 2 : columns;
    final cards = <Widget>[];
    for (final selection in selections) {
      if (cards.length >= wanted) break;
      try {
        cards.add(
          InsightCardFrame(
            card: selection.card,
            child: selection.build(context),
          ),
        );
      } catch (e, stack) {
        logger.e(
          'Insight card ${selection.card.id} failed to build',
          error: e,
          stackTrace: stack,
        );
      }
    }
    if (cards.isEmpty) return const SizedBox.shrink();

    // Rows keep the column width even when short of cards: a lone card
    // stretched across a desktop window is mostly empty space.
    final perRow = columns;
    final height = insightCardHeight(MediaQuery.textScalerOf(context));
    return Column(
      children: [
        for (var start = 0; start < cards.length; start += perRow) ...[
          if (start > 0) const SizedBox(height: _cardGap),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + perRow; i++) ...[
                  if (i > start) const SizedBox(width: _cardGap),
                  Expanded(
                    child: i < cards.length ? cards[i] : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Uniform card frame: small uppercase header row, then the card's body in
/// the remaining space.
class InsightCardFrame extends StatelessWidget {
  final InsightCard<dynamic> card;
  final Widget child;

  const InsightCardFrame({super.key, required this.card, required this.child});

  @override
  Widget build(BuildContext context) {
    final muted = context.theme.colorScheme.onSurfaceVariant;
    return DionContainer(
      color: context.theme.colorScheme.surfaceContainer,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(DionSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(card.icon, size: 13, color: muted),
                const SizedBox(width: DionSpacing.xs + 2),
                Flexible(
                  child: Text(
                    card.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DionTypography.sectionHeader(muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DionSpacing.sm + 2),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
