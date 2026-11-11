import 'dart:math' as math;

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:dionysos/views/dialog/day_details.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Month picker for the calendar: a year of month tiles tinted by time
/// spent, with a breakdown of the focused month underneath. Tapping a tile
/// focuses it, tapping the focused tile (or "Open") jumps there. Resolves to
/// the picked month, or null when dismissed.
Future<DateTime?> showMonthOverview(
  BuildContext context, {
  required DateTime selected,
}) {
  return showDionPanel<DateTime>(
    context: context,
    builder: (_) => _MonthOverviewPanel(selected: selected),
  );
}

Color _accent(BuildContext context) =>
    context.isDarkMode ? DionColors.primary : DionColors.primaryDark;

DateTime _currentMonth() {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
}

class _EntryStat {
  final Entry entry;
  Duration duration = Duration.zero;
  int sessions = 0;
  final Set<int> episodes = {};

  _EntryStat(this.entry);
}

class _MonthStats {
  final DateTime month;

  /// Time spent per day of the month, index 0 is the 1st.
  final List<Duration> days;
  final Map<String, Duration> byVerb;

  /// Most time spent first.
  final List<_EntryStat> entries;
  final List<DayRelease> releases;
  final Duration total;

  const _MonthStats._(
    this.month,
    this.days,
    this.byVerb,
    this.entries,
    this.releases,
    this.total,
  );

  factory _MonthStats.build(
    DateTime month,
    List<EpisodeActivity> activities,
    Map<String, Entry> resolved,
    List<DayRelease> releases,
  ) {
    final days = List.filled(
      DateTime(month.year, month.month + 1, 0).day,
      Duration.zero,
    );
    final byVerb = <String, Duration>{};
    final byEntry = <String, _EntryStat>{};
    var total = Duration.zero;
    for (final activity in activities) {
      days[activity.time.toLocal().day - 1] += activity.duration;
      total += activity.duration;
      final verb = activity.entry.mediaType.activityVerb;
      byVerb[verb] = (byVerb[verb] ?? Duration.zero) + activity.duration;
      final uid = activity.entry.id.uid;
      final stat = byEntry.putIfAbsent(
        uid,
        () => _EntryStat(resolved[uid] ?? activity.entry),
      );
      stat.duration += activity.duration;
      stat.sessions++;
      final from = math.min(activity.fromepisode, activity.toepisode);
      final to = math.max(activity.fromepisode, activity.toepisode);
      // Bounded so a corrupt range can't stall the popup.
      for (var ep = from; ep <= to && ep - from < 2000; ep++) {
        stat.episodes.add(ep);
      }
    }
    final entries = byEntry.values.toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    return _MonthStats._(month, days, byVerb, entries, releases, total);
  }

  bool get hasActivity => total > Duration.zero;

  bool get isFuture => month.isAfter(_currentMonth());

  bool get isCurrent => month == _currentMonth();

  int get activeDays => days.where((d) => d > Duration.zero).length;

  /// Days that could have had activity so far: all of them for past months.
  int get elapsedDays => isCurrent ? DateTime.now().day : days.length;

  int get longestStreak {
    var best = 0;
    var run = 0;
    for (final day in days) {
      run = day > Duration.zero ? run + 1 : 0;
      best = math.max(best, run);
    }
    return best;
  }

  /// 1-based day with the most time spent, null without activity.
  int? get busiestDay {
    if (!hasActivity) return null;
    var best = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i] > days[best]) best = i;
    }
    return best + 1;
  }
}

class _YearData {
  final int year;
  final List<_MonthStats> months;

  /// December of the year before, so January has something to compare to.
  final _MonthStats previousDecember;
  final int titles;

  const _YearData._(this.year, this.months, this.previousDecember, this.titles);

  static Future<_YearData> load(int year) async {
    final db = locate<Database>();
    final start = DateTime(year - 1, 12);
    final end = DateTime(year + 1);
    // Only upcoming months can have scheduled releases; skip paging the
    // whole library for past years.
    final releasesFuture = end.isAfter(_currentMonth())
        ? loadReleasesBetween(DateTime(year), end)
        : Future.value(const <DayRelease>[]);
    final (raw, releases) = await (
      db.getActivitiesBetween(start, end),
      releasesFuture,
    ).wait;
    final activities = raw
        .whereType<EpisodeActivity>()
        .where((a) => a.duration > Duration.zero)
        .toList();
    final resolved = await db.resolveActivityEntries(activities);

    int keyOf(DateTime time) {
      final local = time.toLocal();
      return local.year * 12 + local.month - 1;
    }

    final activitiesByMonth = <int, List<EpisodeActivity>>{};
    for (final activity in activities) {
      activitiesByMonth
          .putIfAbsent(keyOf(activity.time), () => [])
          .add(activity);
    }
    final releasesByMonth = <int, List<DayRelease>>{};
    for (final release in releases) {
      releasesByMonth
          .putIfAbsent(keyOf(release.release), () => [])
          .add(release);
    }

    _MonthStats statsFor(DateTime month) {
      final key = month.year * 12 + month.month - 1;
      return _MonthStats.build(
        month,
        activitiesByMonth[key] ?? const [],
        resolved,
        releasesByMonth[key] ?? const [],
      );
    }

    final months = [for (var m = 1; m <= 12; m++) statsFor(DateTime(year, m))];
    final titles = {
      for (final month in months)
        for (final stat in month.entries) stat.entry.id.uid,
    }.length;
    return _YearData._(year, months, statsFor(DateTime(year - 1, 12)), titles);
  }

  Duration get total =>
      months.fold(Duration.zero, (sum, month) => sum + month.total);

  Duration get maxMonth => months.fold(
    Duration.zero,
    (max, month) => month.total > max ? month.total : max,
  );

  _MonthStats? get peakMonth {
    final peak = maxMonth;
    if (peak <= Duration.zero) return null;
    return months.firstWhere((m) => m.total == peak);
  }

  _MonthStats previousOf(int month) =>
      month == 1 ? previousDecember : months[month - 2];
}

class _MonthOverviewPanel extends StatefulWidget {
  final DateTime selected;

  const _MonthOverviewPanel({required this.selected});

  @override
  State<_MonthOverviewPanel> createState() => _MonthOverviewPanelState();
}

class _MonthOverviewPanelState extends State<_MonthOverviewPanel> {
  final _years = <int, Future<_YearData>>{};
  late int _year = widget.selected.year;
  late int _focusedMonth = widget.selected.month;

  /// Last loaded year, kept on screen (dimmed) while another year loads so
  /// the panel doesn't collapse to a spinner and jump in size.
  _YearData? _shown;

  int get _maxYear => DateTime.now().year + 1;

  Future<_YearData> _yearFuture(int year) =>
      _years.putIfAbsent(year, () => _YearData.load(year));

  void _shiftYear(int delta) => setState(() => _year += delta);

  void _open(int month) => Navigator.of(context).pop(DateTime(_year, month));

  void _tapMonth(int month) {
    if (month == _focusedMonth) {
      _open(month);
      return;
    }
    setState(() => _focusedMonth = month);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DionSpacing.sm,
              DionSpacing.md,
              DionSpacing.sm,
              DionSpacing.xs,
            ),
            child: Row(
              children: [
                // Balances the close button so the year stays centered.
                const SizedBox(width: 40),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DionIconbutton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous year',
                        onPressed: () => _shiftYear(-1),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '$_year',
                          textAlign: TextAlign.center,
                          style: context.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next year',
                        onPressed: _year < _maxYear
                            ? () => _shiftYear(1)
                            : null,
                      ),
                    ],
                  ),
                ),
                DionIconbutton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: FutureBuilder<_YearData>(
              future: _yearFuture(_year),
              builder: (context, snapshot) {
                final data = snapshot.data;
                if (data != null && data.year == _year) _shown = data;
                final shown = _shown;
                if (shown == null ||
                    (snapshot.hasError && shown.year != _year)) {
                  if (snapshot.hasError) {
                    return ErrorDisplay(
                      e: snapshot.error,
                      s: snapshot.stackTrace,
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(DionSpacing.xxl),
                    child: Center(child: DionProgressBar()),
                  );
                }
                final stale = shown.year != _year;
                final focused = shown.months[_focusedMonth - 1];
                return AnimatedOpacity(
                  duration: DionDuration.normal,
                  opacity: stale ? 0.4 : 1,
                  child: IgnorePointer(
                    ignoring: stale,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        DionSpacing.lg,
                        0,
                        DionSpacing.lg,
                        DionSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _YearSummary(data: shown),
                          const SizedBox(height: DionSpacing.md),
                          _MonthTiles(
                            data: shown,
                            focusedMonth: _focusedMonth,
                            selected: widget.selected,
                            onTap: _tapMonth,
                          ),
                          const SizedBox(height: DionSpacing.lg),
                          Container(height: 1, color: context.dionDivider),
                          const SizedBox(height: DionSpacing.md),
                          AnimatedSwitcher(
                            duration: DionDuration.normal,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topCenter,
                              children: [...previous, ?current],
                            ),
                            child: _MonthDetails(
                              key: ValueKey(focused.month),
                              stats: focused,
                              previous: shown.previousOf(_focusedMonth),
                              onOpen: () => _open(_focusedMonth),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _YearSummary extends StatelessWidget {
  final _YearData data;

  const _YearSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final muted = context.textTertiary;
    final style = context.bodySmall?.copyWith(color: muted);
    final total = data.total;
    if (total <= Duration.zero) {
      return Text(
        'No activity recorded in ${data.year}.',
        textAlign: TextAlign.center,
        style: style,
      );
    }
    final peak = data.peakMonth;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatDurationCompact(total),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          TextSpan(
            text:
                ' in ${data.year} · ${data.titles} '
                '${pluralize(data.titles, 'title')}',
          ),
          if (peak != null)
            TextSpan(
              text: ' · peak in ${DateFormat.MMMM().format(peak.month)}',
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _MonthTiles extends StatelessWidget {
  final _YearData data;
  final int focusedMonth;

  /// The month the calendar currently shows.
  final DateTime selected;
  final void Function(int month) onTap;

  const _MonthTiles({
    required this.data,
    required this.focusedMonth,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final max = data.maxMonth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 3 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: DionSpacing.sm,
          crossAxisSpacing: DionSpacing.sm,
          childAspectRatio: 0.95,
          children: [
            for (final stats in data.months)
              _MonthTile(
                stats: stats,
                // Square root so a single huge month doesn't wash out the
                // rest of the year.
                intensity: max <= Duration.zero
                    ? 0
                    : math.sqrt(stats.total.inSeconds / max.inSeconds),
                focused: stats.month.month == focusedMonth,
                selected:
                    stats.month.year == selected.year &&
                    stats.month.month == selected.month,
                onTap: () => onTap(stats.month.month),
              ),
          ],
        );
      },
    );
  }
}

class _MonthTile extends StatelessWidget {
  final _MonthStats stats;
  final double intensity;
  final bool focused;
  final bool selected;
  final VoidCallback onTap;

  const _MonthTile({
    required this.stats,
    required this.intensity,
    required this.focused,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final scheme = context.theme.colorScheme;
    final base = scheme.surfaceContainer;
    final background = intensity > 0
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.1 + 0.4 * intensity),
            base,
          )
        : base;
    final covers = stats.hasActivity
        ? stats.entries.take(3).map((s) => s.entry).toList()
        : stats.releases.take(3).map<Entry>((r) => r.entry).toList();
    final dimmed = stats.isFuture && stats.releases.isEmpty;
    final releaseCount = stats.releases.length;
    final label = stats.hasActivity
        ? formatDurationCompact(stats.total)
        : releaseCount > 0
        ? '$releaseCount ${pluralize(releaseCount, 'release')}'
        : '—';

    final tooltip = [
      DateFormat('MMMM y').format(stats.month),
      if (stats.hasActivity)
        '${stats.entries.length} ${pluralize(stats.entries.length, 'title')}',
      if (stats.hasActivity)
        '${stats.activeDays} active ${pluralize(stats.activeDays, 'day')}',
      if (releaseCount > 0)
        '$releaseCount ${pluralize(releaseCount, 'release')}',
      if (focused) 'Tap again to open',
    ].join(' · ');

    return Semantics(
      selected: focused,
      label: tooltip,
      child: Clickable(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: DionDuration.normal,
          opacity: dimmed ? 0.55 : 1,
          child: AnimatedContainer(
            duration: DionDuration.normal,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(DionRadius.lg),
              border: Border.all(
                color: focused
                    ? accent
                    : selected
                    ? accent.withValues(alpha: 0.4)
                    : scheme.surfaceContainer,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(DionSpacing.sm - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.MMM().format(stats.month),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: context.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: stats.isCurrent ? accent : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (stats.isCurrent)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DionSpacing.xs),
                Expanded(
                  child: covers.isEmpty
                      ? const SizedBox.shrink()
                      // The fan's covers open the detail page on tap; here
                      // the whole tile is the target.
                      : IgnorePointer(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: InsightCoverFan(entries: covers),
                          ),
                        ),
                ),
                const SizedBox(height: DionSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: stats.hasActivity
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDetails extends StatelessWidget {
  final _MonthStats stats;
  final _MonthStats previous;
  final VoidCallback onOpen;

  const _MonthDetails({
    super.key,
    required this.stats,
    required this.previous,
    required this.onOpen,
  });

  static const _maxEntries = 5;
  static const _maxReleases = 5;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    final hasReleases = stats.releases.isNotEmpty;
    final topDuration = stats.entries.isEmpty
        ? Duration.zero
        : stats.entries.first.duration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM y').format(stats.month),
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  _Trend(stats: stats, previous: previous),
                ],
              ),
            ),
            DionTextbutton(
              type: ButtonType.elevated,
              onPressed: onOpen,
              child: const Text('Open'),
            ),
          ],
        ),
        if (stats.hasActivity) ...[
          const SizedBox(height: DionSpacing.md),
          Row(
            children: [
              _Stat(value: formatDurationCompact(stats.total), label: 'total'),
              _Stat(
                value: '${stats.activeDays}/${stats.elapsedDays}',
                label: 'active days',
              ),
              _Stat(
                value:
                    '${stats.longestStreak} '
                    '${pluralize(stats.longestStreak, 'day')}',
                label: 'best streak',
              ),
              _Stat(
                value: DateFormat.MMMd().format(
                  DateTime(
                    stats.month.year,
                    stats.month.month,
                    stats.busiestDay!,
                  ),
                ),
                label: 'busiest day',
              ),
            ],
          ),
          const SizedBox(height: DionSpacing.md),
          SizedBox(
            height: 72,
            child: BarStrip.durations(
              values: stats.days,
              accent: accent,
              labels: {
                for (final i in const [0, 6, 13, 20, 27])
                  if (i < stats.days.length) i: '${i + 1}',
              },
            ),
          ),
          const SizedBox(height: DionSpacing.md),
          Builder(
            builder: (context) {
              final segments = [
                for (final MapEntry(key: verb, value: duration)
                    in stats.byVerb.entries)
                  Segment(
                    label: verb,
                    duration: duration,
                    color: verbColor(context, verb),
                  ),
              ]..sort((a, b) => b.duration.compareTo(a.duration));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentBar(segments: segments, height: 8),
                  const SizedBox(height: DionSpacing.xs + 2),
                  SegmentLegend(segments: segments),
                ],
              );
            },
          ),
          const _SectionHeader('Most time on'),
          for (final stat in stats.entries.take(_maxEntries))
            _EntryRow(stat: stat, topDuration: topDuration),
          if (stats.entries.length > _maxEntries)
            _MutedText(
              '+ ${stats.entries.length - _maxEntries} more '
              '${pluralize(stats.entries.length - _maxEntries, 'title')}',
            ).paddingOnly(top: DionSpacing.xs),
        ],
        if (hasReleases) ...[
          const _SectionHeader('Releases'),
          for (final release in stats.releases.take(_maxReleases))
            _ReleaseRow(release: release),
          if (stats.releases.length > _maxReleases)
            _MutedText('+ ${stats.releases.length - _maxReleases} more')
                .paddingOnly(top: DionSpacing.xs),
        ],
        if (!stats.hasActivity && !hasReleases)
          _MutedText(
            stats.isFuture
                ? 'Nothing scheduled yet.'
                : 'No listening, reading or watching recorded.',
          ).paddingOnly(top: DionSpacing.md),
      ],
    );
  }
}

/// "32% more than February" style caption under the month title.
class _Trend extends StatelessWidget {
  final _MonthStats stats;
  final _MonthStats previous;

  const _Trend({required this.stats, required this.previous});

  @override
  Widget build(BuildContext context) {
    final previousName = DateFormat.MMMM().format(previous.month);
    final (IconData? icon, String text, bool positive) = switch ((
      stats.hasActivity,
      previous.hasActivity,
    )) {
      (false, _) when stats.isFuture => (Icons.event, 'Upcoming', false),
      (false, _) when stats.isCurrent => (
        null,
        'Nothing yet this month',
        false,
      ),
      (false, _) => (null, 'A quiet month', false),
      (true, false) => (
        Icons.north_east,
        'Back after a quiet $previousName',
        true,
      ),
      (true, true) => _compare(previousName),
    };
    final color = positive ? _accent(context) : context.textTertiary;
    return Row(
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: color).paddingOnly(right: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  (IconData?, String, bool) _compare(String previousName) {
    final change =
        (stats.total.inSeconds - previous.total.inSeconds) /
        previous.total.inSeconds;
    final percent = (change * 100).round();
    if (percent == 0) return (Icons.east, 'Same as $previousName', false);
    if (percent > 0) {
      return (Icons.north_east, '$percent% more than $previousName', true);
    }
    return (Icons.south_east, '${-percent}% less than $previousName', false);
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: InsightStyles.hero(context).copyWith(fontSize: 18),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: InsightStyles.label(context),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final _EntryStat stat;
  final Duration topDuration;

  const _EntryRow({required this.stat, required this.topDuration});

  @override
  Widget build(BuildContext context) {
    final entry = stat.entry;
    final media = entry.mediaType;
    final episodes = stat.episodes.length;
    final subtitle = [
      media.activityVerb,
      if (episodes > 0) '$episodes ${media.getEpisodeNames(episodes)}',
      '${stat.sessions} ${pluralize(stat.sessions, 'session')}',
    ].join(' · ');
    final share = topDuration <= Duration.zero
        ? 0.0
        : stat.duration.inSeconds / topDuration.inSeconds;
    return Clickable(
      onTap: () {
        // Push first, then close the popup on top of the detail page.
        context.push('/detail', extra: [entry]);
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 48,
              child: IgnorePointer(child: InsightCover(entry: entry)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: DionSpacing.sm),
                      Text(
                        formatDurationCompact(stat.duration),
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DionRadius.xs),
                    child: Container(
                      height: 3,
                      color: context.theme.colorScheme.surfaceContainerHighest,
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: share.clamp(0.02, 1.0),
                        child: ColoredBox(
                          color: verbColor(context, media.activityVerb),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  final DayRelease release;

  const _ReleaseRow({required this.release});

  @override
  Widget build(BuildContext context) {
    final entry = release.entry;
    return Clickable(
      onTap: () {
        context.push('/detail', extra: [entry]);
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 48,
              child: IgnorePointer(child: InsightCover(entry: entry)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: DionSpacing.sm),
            Text(
              DateFormat.MMMEd().format(release.release.toLocal()),
              style: context.labelSmall?.copyWith(
                color: context.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, DionSpacing.lg, 0, DionSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: DionTypography.sectionHeader(context.textTertiary),
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.bodySmall?.copyWith(color: context.textTertiary),
    );
  }
}
