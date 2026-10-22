import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart' show EntryId;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/views/dialog/day_details.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' show Colors, Icons, Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:intl/intl.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// Month-per-page release calendar: releases render as a cover treemap per
/// day, time spent as a heatmap tint on days without covers.
class ReleaseCalendarView extends StatefulWidget {
  const ReleaseCalendarView({super.key});

  @override
  State<ReleaseCalendarView> createState() => _ReleaseCalendarViewState();
}

class _ReleaseCalendarViewState extends State<ReleaseCalendarView>
    with StateDisposeScopeMixin {
  static const _pageSize = 100;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Future<_MonthData>? _future;

  /// Last successfully loaded data, kept so DB events re-querying the
  /// current month don't blank the grid back to a spinner.
  _MonthData? _shown;

  @override
  void initState() {
    super.initState();
    // The Observer fires on init (post-frame), kicking off the first load.
    Observer(
      _reload,
      Listenable.merge([
        locate<Database>().getListenable(DBEvent.entryAddedOrRemoved),
        locate<Database>().getListenable(DBEvent.entryUpdated),
        locate<Database>().getListenable(DBEvent.categoryUpdated),
        locate<Database>().getListenable(DBEvent.activityUpdated),
      ]),
    ).disposedBy(scope);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _loadMonth(_month);
    });
  }

  bool get _isCurrentMonth => _sameMonth(_month, DateTime.now());

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _future = _loadMonth(_month);
    });
  }

  void _goToCurrentMonth() {
    if (_isCurrentMonth) return;
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _future = _loadMonth(_month);
    });
  }

  Future<_MonthData> _loadMonth(DateTime month) async {
    final db = locate<Database>();
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    // Entry paging and the activities range scan are independent; run them
    // concurrently so the month costs the slower of the two, not the sum.
    final activitiesFuture = db.getActivitiesBetween(monthStart, monthEnd);
    final releases = <DayRelease>[];
    for (var page = 0; ; page++) {
      final pageEntries = await db.getCalendarEntries(page, _pageSize).toList();
      for (final entry in pageEntries) {
        final release = entry.nextRelease;
        if (release == null || entry.status == rust.ReleaseStatus.complete) {
          continue;
        }
        if (release.isBefore(monthStart) || !release.isBefore(monthEnd)) {
          continue;
        }
        releases.add(DayRelease(entry, release));
      }
      if (pageEntries.length < _pageSize) break;
    }
    return _MonthData.build(monthStart, releases, await activitiesFuture);
  }

  void _openDay(DateTime day) {
    final data = _shown;
    if (data == null) return;
    showDayDetails(
      context,
      day: day,
      releases: data.releasesFor(day),
      activities: data.activitiesFor(day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      title: const Text('Calendar'),
      child: FutureBuilder<_MonthData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data != null && _sameMonth(data.month, _month)) {
            _shown = data;
          }
          final shown = _shown;
          if (shown == null || !_sameMonth(shown.month, _month)) {
            if (snapshot.hasError) {
              return Center(
                child: ErrorDisplay(e: snapshot.error, s: snapshot.stackTrace),
              );
            }
            return const Center(child: DionProgressBar());
          }
          return Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: SingleChildScrollView(
                      padding: DionSpacing.pagePadding.copyWith(
                        bottom: DionSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MonthSelector(
                            month: _month,
                            onPrevious: () => _shiftMonth(-1),
                            onNext: () => _shiftMonth(1),
                            showToday: !_isCurrentMonth,
                            onToday: _goToCurrentMonth,
                          ),
                          _MonthSummary(data: shown),
                          const SizedBox(height: DionSpacing.lg),
                          _WeekdayHeader(month: _month),
                          const SizedBox(height: DionSpacing.sm),
                          _MonthGrid(
                            month: _month,
                            data: shown,
                            onDayTap: _openDay,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}

class _MonthData {
  final DateTime month;
  final List<Activity> activities;
  final Map<DateTime, List<DayRelease>> _releasesByDay;
  final Map<DateTime, List<Activity>> _activitiesByDay;
  final Map<DateTime, Duration> _durationByDay;

  /// Busiest day of the month; the heatmap normalizes against it.
  final Duration maxDayDuration;

  const _MonthData._(
    this.month,
    this.activities,
    this._releasesByDay,
    this._activitiesByDay,
    this._durationByDay,
    this.maxDayDuration,
  );

  factory _MonthData.build(
    DateTime month,
    List<DayRelease> releases,
    List<Activity> activities,
  ) {
    final releasesByDay = <DateTime, List<DayRelease>>{};
    for (final release in releases) {
      releasesByDay
          .putIfAbsent(_dayKey(release.release), () => [])
          .add(release);
    }
    for (final dayReleases in releasesByDay.values) {
      dayReleases.sort((a, b) => a.release.compareTo(b.release));
    }

    final activitiesByDay = <DateTime, List<Activity>>{};
    final durationByDay = <DateTime, Duration>{};
    for (final activity in activities) {
      activitiesByDay
          .putIfAbsent(_dayKey(activity.time), () => [])
          .add(activity);
      final duration = activity is EpisodeActivity
          ? activity.duration
          : Duration.zero;
      if (duration <= Duration.zero) continue;
      final day = _dayKey(activity.time);
      durationByDay[day] = (durationByDay[day] ?? Duration.zero) + duration;
    }

    final maxDay = durationByDay.values.fold<Duration>(
      Duration.zero,
      (max, duration) => duration > max ? duration : max,
    );

    return _MonthData._(
      month,
      activities,
      releasesByDay,
      activitiesByDay,
      durationByDay,
      maxDay,
    );
  }

  List<DayRelease> releasesFor(DateTime day) =>
      _releasesByDay[_dayKey(day)] ?? const [];

  List<Activity> activitiesFor(DateTime day) =>
      _activitiesByDay[_dayKey(day)] ?? const [];

  Duration durationFor(DateTime day) =>
      _durationByDay[_dayKey(day)] ?? Duration.zero;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Whether [month] differs from the month the device clock is in; while
  /// false the jump-to-current button hides but keeps its slot so the title
  /// stays centered.
  final bool showToday;
  final VoidCallback onToday;

  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.showToday,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DionSpacing.xs),
      child: Row(
        children: [
          DionIconbutton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM y').format(month),
                style: context.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          DionIconbutton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: onNext,
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IgnorePointer(
              ignoring: !showToday,
              child: AnimatedOpacity(
                duration: DionDuration.fast,
                opacity: showToday ? 1 : 0,
                child: DionIconbutton(
                  icon: const Icon(Icons.today),
                  tooltip: 'Back to current month',
                  onPressed: showToday ? onToday : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final _MonthData data;

  const _MonthSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final chips = mediaStatChips(data.activities.whereType<EpisodeActivity>());
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, DionSpacing.sm, 2, 0),
      child: Wrap(
        spacing: DionSpacing.sm,
        runSpacing: DionSpacing.sm,
        children: chips.isNotEmpty
            ? chips
            : [
                Text(
                  'No listening, reading or watching recorded this month.',
                  style: context.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final DateTime month;

  const _WeekdayHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final leading = (first.weekday - DateTime.monday) % 7;
    final gridStart = first.subtract(Duration(days: leading));
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                DateFormat.E().format(gridStart.add(Duration(days: i))),
                style: context.labelSmall?.copyWith(
                  color: context.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final _MonthData data;
  final void Function(DateTime day) onDayTap;

  const _MonthGrid({
    required this.month,
    required this.data,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final leading = (first.weekday - DateTime.monday) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[];
    for (var i = 0; i < totalCells; i++) {
      final date = first.subtract(Duration(days: leading - i));
      final seen = <(EntryId, String)>{};
      final entries = data
          .activitiesFor(date)
          .where((a) => a is EpisodeActivity && a.duration > Duration.zero)
          .map((e) => (e as EpisodeActivity).entry)
          .where((e) {
            final containsEntry = seen.contains((e.id, e.mediaType.name));
            seen.add((e.id, e.mediaType.name));
            return !containsEntry;
          })
          .toList();
      cells.add(
        _DayCell(
          date: date,
          inMonth: date.year == month.year && date.month == month.month,
          isToday: date == today,
          isFuture: date.isAfter(today),
          releases: data.releasesFor(date),
          entries: entries,
          duration: data.durationFor(date),
          onTap: () => onDayTap(date),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: DionSpacing.xs,
      crossAxisSpacing: DionSpacing.xs,
      // Cells are portrait so covers stay recognizable.
      childAspectRatio: 0.8,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isFuture;
  final List<DayRelease> releases;
  final List<Entry> entries;
  final Duration duration;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isFuture,
    required this.releases,
    required this.entries,
    required this.duration,
    this.onTap,
  });

  static const _cellRadius = BorderRadius.all(Radius.circular(DionRadius.md));

  @override
  Widget build(BuildContext context) {
    final hasReleases = releases.isNotEmpty;
    final hasActivity = duration > Duration.zero;
    final accent = context.isDarkMode
        ? DionColors.primary
        : DionColors.primaryDark;

    final cell = Stack(
      children: [
        if (hasReleases && isFuture)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: _cellRadius,
              child: _DayTreemap(
                releases: releases
                    .take(4)
                    .map((r) => r.entry)
                    .where((r) => r.cover != null)
                    .toList(),
              ),
            ),
          ),
        if (!isFuture && hasActivity)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: _cellRadius,
              child: _DayTreemap(
                releases: entries
                    .take(4)
                    .where((r) => r.cover != null)
                    .toList(),
              ),
            ),
          ),
        if (isFuture)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _cellRadius,
                  color: context.theme.colorScheme.surface.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _cellRadius,
                border: Border.all(
                  color: isToday
                      ? accent
                      : context.theme.colorScheme.surfaceContainer,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            width: context.isCompactWindow ? 15 : 20,
            height: context.isCompactWindow ? 15 : 20,
            decoration: BoxDecoration(
              color: isToday
                  ? accent
                  : context.theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(DionRadius.md),
                bottomRight: Radius.circular(
                  context.isCompactWindow ? DionRadius.md : DionRadius.lg,
                ),
              ),
            ),
            child: Text(
              textAlign: .center,
              '${date.day}',
              style: context.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: context.isCompactWindow ? 10 : 12,
                color: isToday
                    ? Colors.white
                    : context.theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        // if (hasActivity) Im not sure how to visualize this in a nice way
        //   Positioned(
        //     left: 0,
        //     bottom: 0,
        //     child: Container(
        //       width: 15,
        //       height: 15,
        //       decoration: BoxDecoration(
        //         color: _heatColor(context, intensity, saturation: 1),
        //         borderRadius: const BorderRadius.only(
        //           topRight: Radius.circular(DionRadius.xl),
        //           bottomLeft: Radius.circular(DionRadius.md),
        //         ),
        //         border: Border.all(color: context.theme.colorScheme.surfaceContainer),
        //       ),
        //     ),
        //   ),
        // if (hasReleases)
        //   Positioned(
        //     right: 3,
        //     bottom: 3,
        //     child: Container(
        //       width: 17,
        //       height: 17,
        //       decoration: BoxDecoration(
        //         color: accent,
        //         borderRadius: BorderRadius.circular(DionRadius.xl),
        //         border: Border.all(color: context.theme.colorScheme.surface),
        //       ),
        //       child: Text(
        //         textAlign: .center,
        //         releases.length <= 9 ? '${releases.length}' : '9+',
        //         style: const TextStyle(
        //           fontSize: 9.5,
        //           height: 1.3,
        //           fontWeight: FontWeight.w700,
        //           color: Colors.white,
        //         ),
        //       ),
        //     ),
        //   ),
        if (!inMonth)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _cellRadius,
                  color: context.theme.colorScheme.surface.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!inMonth) return cell;

    final tooltip = [
      date.toDateString(),
      if (hasReleases)
        '${releases.length} ${releases.length == 1 ? 'release' : 'releases'}',
      if (hasActivity) duration.formatrelative(),
    ].join(' · ');

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Clickable(
        onTap: onTap,
        child: ClipRRect(borderRadius: _cellRadius, child: cell),
      ),
    );
  }
}

/// Slice-and-dice treemap of up to four release covers in a day cell.
class _DayTreemap extends StatelessWidget {
  final List<Entry> releases;

  const _DayTreemap({required this.releases});

  static const _gapW = SizedBox(width: 1.5);
  static const _gapH = SizedBox(height: 1.5);

  @override
  Widget build(BuildContext context) {
    if (releases.isEmpty) {
      return ColoredBox(
        color: context.theme.colorScheme.surfaceContainerHighest,
      );
    }
    return switch (releases.length) {
      1 => _tile(0),
      2 => Row(
        children: [
          Expanded(child: _tile(0)),
          _gapW,
          Expanded(child: _tile(1)),
        ],
      ),
      3 => Row(
        children: [
          Expanded(child: _tile(0)),
          _gapW,
          Expanded(
            child: Column(
              children: [
                Expanded(child: _tile(1)),
                _gapH,
                Expanded(child: _tile(2)),
              ],
            ),
          ),
        ],
      ),
      _ => Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(0)),
                _gapW,
                Expanded(child: _tile(1)),
              ],
            ),
          ),
          _gapH,
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(2)),
                _gapW,
                Expanded(child: _tile(3)),
              ],
            ),
          ),
        ],
      ),
    };
  }

  Widget _tile(int index) {
    final entry = releases[index];
    final cover = entry.cover;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null)
          DionImage.fromLink(
            link: cover,
            boxFit: BoxFit.cover,
            // A month grid builds up to ~42 cells with up to four tiles each;
            // without a decode bound every cover loads at native resolution.
            cacheWidth: 128,
            errorWidget: _TileFallback(release: releases[index]),
            loadingBuilder: (context) => ColoredBox(
              color: context.theme.colorScheme.surfaceContainerHighest,
            ),
          )
        else
          _TileFallback(release: releases[index]),
        // Top scrim keeps the day number readable over bright covers.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TileFallback extends StatelessWidget {
  final Entry release;

  const _TileFallback({required this.release});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        release.mediaType.icon,
        size: 12,
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
