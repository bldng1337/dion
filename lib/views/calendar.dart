import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/views/dialog/next_release.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class ReleaseCalendarView extends StatefulWidget {
  const ReleaseCalendarView({super.key});

  @override
  State<ReleaseCalendarView> createState() => _ReleaseCalendarViewState();
}

class _ReleaseCalendarViewState extends State<ReleaseCalendarView>
    with StateDisposeScopeMixin {
  static const _pageSize = 100;

  static const _daySections = 14;

  Future<List<_CalendarEntry>>? _future;

  @override
  void initState() {
    super.initState();
    Observer(_reload, locate<Database>().globalListenable).disposedBy(scope);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<List<_CalendarEntry>> _load() async {
    final db = locate<Database>();
    final entries = <EntrySaved>[];
    for (var page = 0; ; page++) {
      final pageEntries = await db.getEntries(page, _pageSize).toList();
      entries.addAll(pageEntries);
      if (pageEntries.length < _pageSize) break;
    }
    return entries
        .where(
          (e) =>
              e.nextRelease != null && e.status != rust.ReleaseStatus.complete,
        )
        .map((e) => _CalendarEntry(e, e.nextRelease!))
        .toList()
      ..sort((a, b) => a.release.compareTo(b.release));
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      title: const Text('Calendar'),
      child: _future == null
          ? const SizedBox.shrink()
          : FutureBuilder<List<_CalendarEntry>>(
              future: _future,
              builder: (context, snapshot) {
                final entries = snapshot.data;
                if (entries == null) {
                  return const Center(child: DionProgressBar());
                }
                if (entries.isEmpty) {
                  return const _EmptyCalendar();
                }
                final sections = _buildSections(entries);
                return ListView.builder(
                  padding: DionSpacing.pagePadding
                      .copyWith(bottom: DionSpacing.xxxl),
                  itemCount: sections.length,
                  itemBuilder: (context, index) => sections[index].render(
                    context,
                  ),
                );
              },
            ),
    );
  }

  List<_CalendarSection> _buildSections(List<_CalendarEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sections = <_CalendarSection>[];

    final overdue = entries.where((e) => e.release.isBefore(today)).toList();
    if (overdue.isNotEmpty) {
      sections.add(
        _CalendarSection(title: 'Overdue', highlight: true, entries: overdue),
      );
    }
    for (var day = 0; day < _daySections; day++) {
      final dayStart = today.add(Duration(days: day));
      final dayEntries = entries
          .where(
            (e) =>
                !e.release.isBefore(dayStart) &&
                e.release.isBefore(dayStart.add(const Duration(days: 1))),
          )
          .toList();
      if (dayEntries.isEmpty) continue;
      sections.add(
        _CalendarSection(
          title: switch (day) {
            0 => 'Today',
            1 => 'Tomorrow',
            _ => DateFormat(
              'EEEE, MMM d',
            ).format(today.add(Duration(days: day))),
          },
          entries: dayEntries,
        ),
      );
    }
    final horizon = today.add(const Duration(days: _daySections));
    final later = entries.where((e) => !e.release.isBefore(horizon)).toList();
    if (later.isNotEmpty) {
      sections.add(_CalendarSection(title: 'Later', entries: later));
    }
    return sections;
  }
}

class _CalendarEntry {
  final EntrySaved entry;
  final DateTime release;

  const _CalendarEntry(this.entry, this.release);
}

class _CalendarSection {
  final String title;
  final List<_CalendarEntry> entries;
  final bool highlight;

  const _CalendarSection({
    required this.title,
    required this.entries,
    this.highlight = false,
  });

  Widget render(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            title,
            style: context.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: highlight
                  ? context.theme.colorScheme.error
                  : context.theme.colorScheme.onSurface,
            ),
          ),
        ),
        for (final e in entries) _CalendarItem(item: e),
      ],
    );
  }}

class _CalendarItem extends StatelessWidget {
  final _CalendarEntry item;

  const _CalendarItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final manual = entry.nextReleaseOverride != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Clickable(
        onTap: () => context.push('/detail', extra: [entry]),
        onLongTap: () => showNextReleaseEditor(context, entry),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: DionContainer(
            color: context.theme.colorScheme.surfaceContainer,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  height: 72,
                  child: DionImage(
                    imageUrl: entry.cover?.url,
                    boxFit: BoxFit.cover,
                    httpHeaders: entry.cover?.header,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              manual ? Icons.event : Icons.auto_awesome,
                              size: 13,
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ).paddingOnly(right: 4),
                            Text(
                              manual ? 'Set manually' : 'Predicted',
                              style: context.labelSmall?.copyWith(
                                color: context.theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 11.5,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              item.release.formatrelative(allowFromNow: true),
                              style: context.labelSmall?.copyWith(
                                color: context.theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy,
            size: 42,
            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: DionSpacing.md),
          Text(
            'No upcoming releases',
            style: context.titleMedium?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: DionSpacing.xs),
          Text(
            'Predictions appear here automatically once entries have\n'
            'episode timestamps; you can also set a date manually\n'
            "from an entry's detail page.",
            textAlign: TextAlign.center,
            style: context.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
