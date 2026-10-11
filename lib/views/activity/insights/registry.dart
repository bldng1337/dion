import 'dart:math';

import 'package:dionysos/utils/log.dart';
import 'package:dionysos/views/activity/insights/cards/binge_card.dart';
import 'package:dionysos/views/activity/insights/cards/busiest_day_card.dart';
import 'package:dionysos/views/activity/insights/cards/comeback_card.dart';
import 'package:dionysos/views/activity/insights/cards/days_as_covers_card.dart';
import 'package:dionysos/views/activity/insights/cards/streak_card.dart';
import 'package:dionysos/views/activity/insights/cards/top_tag_card.dart';
import 'package:dionysos/views/activity/insights/cards/total_time_card.dart';
import 'package:dionysos/views/activity/insights/cards/total_tracked_card.dart';
import 'package:dionysos/views/activity/insights/cards/typical_time_card.dart';
import 'package:dionysos/views/activity/insights/cards/weekday_card.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';

/// Every card type the daily picker can draw from. A new card is a class in
/// `cards/` plus one entry here.
final List<InsightCard<dynamic>> insightCards = [
  const StreakCard(),
  const TotalTimeCard(),
  const BusiestDayCard(),
  const TypicalTimeCard(),
  const BingeCard(),
  const ComebackCard(),
  const TopTagCard(),
  const DaysAsCoversCard(),
  const TotalTrackedCard(),
  const WeekdayCard(),
];

/// Runs every card's applicability check and picks up to [count] of the
/// applicable ones. Sampling is weighted and seeded from the day, so the
/// choice changes daily but stays stable across rebuilds, navigation and
/// window resizes. A card that throws is logged and skipped so one broken
/// card never takes the section down.
Future<List<InsightSelection<dynamic>>> selectInsightCards(
  InsightContext context, {
  int count = 2,
}) async {
  final applicable = <InsightSelection<dynamic>>[];
  for (final card in insightCards) {
    try {
      final data = await card.compute(context);
      if (data != null) {
        applicable.add(InsightSelection(card, data));
      }
    } catch (e, stack) {
      logger.e(
        'Insight card ${card.id} failed to compute',
        error: e,
        stackTrace: stack,
      );
    }
  }
  if (applicable.length <= count) return applicable;

  final now = context.now;
  final random = Random(now.year * 10000 + now.month * 100 + now.day);
  final pool = [...applicable];
  var remainingWeight = pool.fold<double>(
    0,
    (sum, pick) => sum + pick.card.weight,
  );
  final picked = <InsightSelection<dynamic>>[];
  while (picked.length < count && pool.isNotEmpty) {
    var dart = random.nextDouble() * remainingWeight;
    var index = pool.length - 1;
    for (var i = 0; i < pool.length; i++) {
      dart -= pool[i].card.weight;
      if (dart <= 0) {
        index = i;
        break;
      }
    }
    remainingWeight -= pool[index].card.weight;
    picked.add(pool.removeAt(index));
  }
  return picked;
}
