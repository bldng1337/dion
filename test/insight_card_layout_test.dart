import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/views/activity/insights/cards/binge_card.dart';
import 'package:dionysos/views/activity/insights/cards/busiest_day_card.dart';
import 'package:dionysos/views/activity/insights/cards/comeback_card.dart';
import 'package:dionysos/views/activity/insights/cards/consistency_card.dart';
import 'package:dionysos/views/activity/insights/cards/days_as_covers_card.dart';
import 'package:dionysos/views/activity/insights/cards/devices_card.dart';
import 'package:dionysos/views/activity/insights/cards/fresh_picks_card.dart';
import 'package:dionysos/views/activity/insights/cards/on_repeat_card.dart';
import 'package:dionysos/views/activity/insights/cards/session_length_card.dart';
import 'package:dionysos/views/activity/insights/cards/streak_card.dart';
import 'package:dionysos/views/activity/insights/cards/top_tag_card.dart';
import 'package:dionysos/views/activity/insights/cards/total_time_card.dart';
import 'package:dionysos/views/activity/insights/cards/total_tracked_card.dart';
import 'package:dionysos/views/activity/insights/cards/typical_time_card.dart';
import 'package:dionysos/views/activity/insights/cards/weekday_card.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insights_section.dart';
import 'package:dionysos/views/activity/insights/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// Only the members the insight cards read; anything else fails loudly.
class _FakeEntry implements Entry {
  @override
  final String title;
  @override
  final rust.Link? cover;

  _FakeEntry(this.title, this.cover);

  @override
  rust.EntryId get id => rust.EntryId(uid: title);

  @override
  rust.MediaType get mediaType => rust.MediaType.comic;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Covers that never produce an image, each taking a different DionImage
/// path: no link, an unfetched scheme, and a network load that fails.
const _covers = <String, rust.Link?>{
  'no cover': null,
  'mihon cover': rust.Link(url: 'mihon:cover'),
  'failing cover': rust.Link(url: 'https://example.invalid/cover.png'),
};

const _widths = [180.0, 260.0, 328.0, 420.0, 600.0, 1200.0];
const _textScales = [1.0, 1.3, 2.0];

List<InsightSelection<dynamic>> _samples(rust.Link? cover) {
  Entry entry(String title) => _FakeEntry(title, cover);
  final day = DateTime.utc(2026, 11, 10);
  const long = 'An Unreasonably Long Title That Never Fits On One Line';
  return [
    InsightSelection(
      const StreakCard(),
      StreakData(
        current: 12,
        longest: 40,
        activeToday: false,
        recent: List.generate(30, (i) => i % 4 != 0),
      ),
    ),
    const InsightSelection(
      TotalTimeCard(),
      TotalTimeData(
        current: {
          'Read': Duration(hours: 9, minutes: 12),
          'Watched': Duration(hours: 4),
          'Listened': Duration(hours: 2, minutes: 5),
        },
        currentTotal: Duration(hours: 15, minutes: 17),
        previousTotal: Duration(hours: 7),
      ),
    ),
    InsightSelection(
      const BusiestDayCard(),
      BusiestDayData(
        day: day,
        total: const Duration(hours: 6, minutes: 40),
        entry: entry(long),
        entryDuration: const Duration(hours: 5),
      ),
    ),
    InsightSelection(
      const TypicalTimeCard(),
      TypicalTimeData(
        fromHour: 22,
        toHour: 0,
        verbNoun: 'reading',
        histogram: List.generate(24, (i) => Duration(minutes: i * 7)),
        share: 0.42,
      ),
    ),
    InsightSelection(
      const BingeCard(),
      BingeData(
        entry: entry(long),
        duration: const Duration(hours: 3, minutes: 5),
        episodes: 14,
        day: day,
      ),
    ),
    InsightSelection(
      const ComebackCard(),
      ComebackData(entry: entry('Back Again'), gapDays: 123, returnedOn: day),
    ),
    InsightSelection(
      const TopTagCard(),
      TopTagData(
        tag: 'Slice of Life and Other Long Tags',
        duration: const Duration(days: 2, hours: 3),
        entryCount: 17,
        topEntries: [entry('A'), entry('B'), entry('C')],
      ),
    ),
    InsightSelection(
      const DaysAsCoversCard(),
      DaysAsCoversData(
        today: day,
        days: [
          for (var i = 0; i < 7; i++)
            (
              day.subtract(Duration(days: 6 - i)),
              i.isEven ? entry('Day $i') : null,
            ),
        ],
      ),
    ),
    InsightSelection(
      const TotalTrackedCard(),
      TotalTrackedData(
        total: const Duration(days: 45, hours: 4),
        titles: 52,
        episodes: 872,
        last30Days: List.generate(30, (i) => Duration(minutes: (i * 37) % 90)),
      ),
    ),
    InsightSelection(
      const WeekdayCard(),
      WeekdayData(
        topWeekday: 2,
        share: 0.31,
        perWeekday: List.generate(7, (i) => Duration(hours: i + 1)),
      ),
    ),
    InsightSelection(
      const OnRepeatCard(),
      OnRepeatData(
        entry: entry(long),
        duration: const Duration(hours: 18),
        share: 0.64,
        sessions: 31,
      ),
    ),
    InsightSelection(
      const FreshPicksCard(),
      FreshPicksData(
        count: 7,
        duration: const Duration(hours: 11),
        latest: [entry('X'), entry('Y'), entry('Z')],
      ),
    ),
    InsightSelection(
      const ConsistencyCard(),
      ConsistencyData(
        days: List.generate(28, (i) => Duration(minutes: (i * 23) % 70)),
        todayIndex: 23,
        activeDays: 19,
        total: const Duration(hours: 30),
      ),
    ),
    const InsightSelection(
      DevicesCard(),
      DevicesData(
        devices: [
          ('Pixel 9 Pro Fold With A Long Name', Duration(hours: 20)),
          ('Desktop', Duration(hours: 8)),
          ('Tablet', Duration(hours: 3)),
          ('Other', Duration(minutes: 40)),
        ],
        deviceCount: 5,
      ),
    ),
    const InsightSelection(
      SessionLengthCard(),
      SessionLengthData(
        median: Duration(minutes: 42),
        sessions: 318,
        buckets: [40, 90, 120, 50, 18],
      ),
    ),
  ];
}

Widget _app({required double textScale, required Widget child}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

List<Object> _drainExceptions(WidgetTester tester) {
  final errors = <Object>[];
  for (Object? e = tester.takeException(); e != null;) {
    errors.add(e);
    e = tester.takeException();
  }
  return errors;
}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1400, 2400);
    view.devicePixelRatio = 1;
  });

  test('every registered card has a layout sample', () {
    expect(
      _samples(null).map((s) => s.card.id).toSet(),
      insightCards.map((c) => c.id).toSet(),
    );
  });

  for (final MapEntry(key: coverName, value: cover) in _covers.entries) {
    for (final sample in _samples(cover)) {
      testWidgets('${sample.card.id} fits every card size ($coverName)', (
        tester,
      ) async {
        for (final scale in _textScales) {
          for (final width in _widths) {
            final height = insightCardHeight(TextScaler.linear(scale));
            await tester.pumpWidget(
              _app(
                textScale: scale,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Builder(
                    builder: (context) => InsightCardFrame(
                      card: sample.card,
                      child: sample.build(context),
                    ),
                  ),
                ),
              ),
            );
            // Lets failing image loads settle into their fallback.
            await tester.pump(const Duration(milliseconds: 500));
            final errors = _drainExceptions(tester);
            expect(
              errors,
              isEmpty,
              reason:
                  '${width}x$height at ${scale}x text:\n'
                  '${errors.join('\n')}',
            );
            expect(
              find.byWidgetPredicate(
                (w) => w is Text && (w.style?.fontSize ?? 1) <= 0,
              ),
              findsNothing,
              reason: 'zero-size text at ${width}x$height',
            );
          }
        }
      });
    }
  }

  testWidgets('grid columns follow the available width', (tester) async {
    final selections = _samples(null);
    for (final (width, columns, cards) in [
      (328.0, 1, 2),
      (620.0, 2, 2),
      (1000.0, 3, 3),
    ]) {
      expect(insightColumnsFor(width), columns);
      await tester.pumpWidget(
        _app(
          textScale: 1,
          child: SizedBox(
            width: width,
            child: InsightGrid(selections: selections, width: width),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_drainExceptions(tester), isEmpty);
      expect(find.byType(InsightCardFrame), findsNWidgets(cards));
    }
  });

  test('cards compute from a realistic history', () async {
    final now = DateTime.utc(2026, 11, 11, 20);
    final entries = [
      for (final t in ['Alpha', 'Beta', 'Gamma']) _FakeEntry(t, null),
    ];
    const phone = DeviceRef(deviceId: 'phone', name: 'Phone');
    const desktop = DeviceRef(deviceId: 'desktop', name: 'Desktop');
    final activities = <EpisodeActivity>[
      for (var day = 59; day >= 0; day--)
        if (day % 3 != 1)
          EpisodeActivity(
            fromepisode: day,
            toepisode: day + 2,
            entry: day < 20 ? entries[day % 2] : entries[2],
            extensionid: 'test',
            duration: Duration(minutes: 20 + (day * 13) % 100),
            time: now.subtract(Duration(days: day, hours: day % 3)),
            id: 'a$day',
            device: day.isEven ? phone : desktop,
          ),
      // A late newcomer, so there is something fresh to pick up.
      EpisodeActivity(
        fromepisode: 1,
        toepisode: 1,
        entry: _FakeEntry('Delta', null),
        extensionid: 'test',
        duration: const Duration(minutes: 30),
        time: now.subtract(const Duration(hours: 1)),
        id: 'delta',
        device: phone,
      ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    final dailyTotals = <DateTime, Duration>{};
    for (final activity in activities) {
      final day = InsightContext.dayKeyOf(activity.time);
      dailyTotals[day] =
          (dailyTotals[day] ?? Duration.zero) + activity.duration;
    }
    final context = InsightContext(
      now: now,
      activities: activities,
      dailyTotals: dailyTotals,
      entriesByUid: const {},
    );

    for (final card in insightCards) {
      await expectLater(card.compute(context), completes, reason: card.id);
    }
    final applicable = {
      for (final s in await selectInsightCards(context)) s.card.id,
    };
    expect(
      applicable,
      containsAll([
        'streak',
        'onRepeat',
        'freshPicks',
        'consistency',
        'devices',
        'sessionLength',
        'daysAsCovers',
      ]),
    );
  });
}
