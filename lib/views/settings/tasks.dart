import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';

class ActiveTasksSettings extends StatelessWidget {
  const ActiveTasksSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Active Tasks'),
      child: _TasksBody(manager: locate<TaskManager>()),
    );
  }
}

class _TasksBody extends StatefulWidget {
  final TaskManager manager;

  const _TasksBody({required this.manager});

  @override
  State<_TasksBody> createState() => _TasksBodyState();
}

class _TasksBodyState extends State<_TasksBody> {
  final Set<Task> _subscribed = {};

  void _onChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_TasksBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.removeListener(_onChange);
      widget.manager.addListener(_onChange);
      for (final task in _subscribed.toList()) {
        task.removeListener(_onChange);
      }
      _subscribed.clear();
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onChange);
    for (final task in _subscribed) {
      task.removeListener(_onChange);
    }
    super.dispose();
  }

  void _syncSubscriptions(List<Task> tasks) {
    final current = tasks.toSet();
    for (final task in _subscribed.toList()) {
      if (!current.contains(task)) {
        task.removeListener(_onChange);
        _subscribed.remove(task);
      }
    }
    for (final task in tasks) {
      if (_subscribed.add(task)) {
        task.addListener(_onChange);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.manager.root
        .traverseBreathFirst()
        .expand((cat) => cat.tasks)
        .toList();
    _syncSubscriptions(tasks);

    final running = tasks.where((t) => t.taskstatus == TaskStatus.running);
    final failed = tasks.where((t) => t.taskstatus == TaskStatus.error);
    final pending = tasks.where((t) => t.taskstatus == TaskStatus.idle);
    final hasFailures = failed.isNotEmpty;

    Widget body;
    if (tasks.isEmpty) {
      body = Center(child: _EmptyState());
    } else {
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Overview(
              total: tasks.length,
              runningCount: running.length,
              failedCount: failed.length,
              pendingCount: pending.length,
              overallProgress: _overallProgress(running),
            ),
            if (running.isNotEmpty)
              SettingTitle(
                title: 'Running · ${running.length}',
                icon: Icons.play_arrow_rounded,
                children: [
                  for (final task in running)
                    _TaskRow(key: ObjectKey(task), task: task),
                ],
              ),
            if (hasFailures)
              SettingTitle(
                title: 'Failed · ${failed.length}',
                icon: Icons.error_outline,
                children: [
                  for (final task in failed)
                    _TaskRow(key: ObjectKey(task), task: task),
                  _ActionRow(
                    icon: Icons.delete_sweep_outlined,
                    label: 'Dismiss all failed tasks',
                    destructive: true,
                    onTap: () {
                      for (final task in failed.toList()) {
                        task.dismiss();
                      }
                    },
                  ),
                ],
              ),
            if (pending.isNotEmpty)
              SettingTitle(
                title: 'Pending · ${pending.length}',
                icon: Icons.schedule,
                children: [
                  for (final task in pending)
                    _TaskRow(key: ObjectKey(task), task: task),
                ],
              ),
            const SizedBox(height: DionSpacing.xl),
          ],
        ),
      );
    }
    return body;
  }

  static double? _overallProgress(Iterable<Task> tasks) {
    final measured = tasks
        .where((task) => task.progress != null)
        .map((task) => task.progress!)
        .toList();
    if (measured.isEmpty) return null;
    return measured.fold<double>(0, (a, b) => a + b) / measured.length;
  }
}

Color _accentFor(BuildContext context, TaskStatus status) => switch (status) {
  TaskStatus.error => DionColors.error,
  TaskStatus.running =>
    context.isDarkMode ? DionColors.primary : DionColors.primaryDark,
  TaskStatus.idle => context.textTertiary,
};

String? _categoryPath(TaskCategory? category) {
  if (category == null) return null;
  final names = <String>[];
  TaskCategory? current = category;
  while (current != null) {
    if (current.parent == null) break; // skip root label
    names.insert(0, current.name);
    current = current.parent;
  }
  if (names.isEmpty) return null;
  return names.join(' / ');
}

class _Overview extends StatelessWidget {
  final int total;
  final int runningCount;
  final int failedCount;
  final int pendingCount;
  final double? overallProgress;

  const _Overview({
    required this.total,
    required this.runningCount,
    required this.failedCount,
    required this.pendingCount,
    this.overallProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DionSpacing.md,
        DionSpacing.md,
        DionSpacing.md,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: DionRadius.medium,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatChip(
                  icon: Icons.play_arrow_rounded,
                  label: 'Running',
                  count: runningCount,
                  accent: _accentFor(context, TaskStatus.running),
                ),
                const SizedBox(width: DionSpacing.lg),
                _StatChip(
                  icon: Icons.schedule,
                  label: 'Pending',
                  count: pendingCount,
                  accent: _accentFor(context, TaskStatus.idle),
                ),
                const SizedBox(width: DionSpacing.lg),
                _StatChip(
                  icon: Icons.error_outline,
                  label: 'Failed',
                  count: failedCount,
                  accent: DionColors.error,
                ),
              ],
            ),
            if (overallProgress != null) ...[
              const SizedBox(height: DionSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(DionRadius.xs),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color accent;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: count > 0 ? 0.12 : 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(width: DionSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count', style: context.titleSmall),
                Text(
                  label.toUpperCase(),
                  style: DionTypography.labelSmall(context.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Task task;

  const _TaskRow({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final status = task.taskstatus;
    final accent = _accentFor(context, status);
    final path = _categoryPath(task.category);
    final isFailed = status == TaskStatus.error;

    final metaParts = [
      if (path != null) path,
      switch (status) {
        TaskStatus.running => task.status,
        TaskStatus.idle => 'Pending',
        TaskStatus.error => task.error.toString(),
      },
    ];
    final metaText = metaParts.join('  ·  ');

    return Material(
      color: const Color(0x00000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Row(
          children: [
            _StatusGlyph(task: task, accent: accent),
            const SizedBox(width: DionSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.name,
                    style: DionTypography.titleSmall(context.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metaText,
                    style: DionTypography.bodySmall(
                      isFailed
                          ? DionColors.error.withValues(alpha: 0.85)
                          : context.textTertiary,
                    ),
                    maxLines: isFailed ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DionSpacing.sm),
            ...switch (status) {
              TaskStatus.running => [
                DionIconbutton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Cancel',
                  onPressed: task.cancel,
                ),
              ],
              TaskStatus.error => [
                DionIconbutton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Retry',
                  onPressed: task.run,
                ),
                DionIconbutton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Dismiss',
                  onPressed: task.dismiss,
                ),
              ],
              TaskStatus.idle => [
                DionIconbutton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  tooltip: 'Dismiss',
                  onPressed: task.dismiss,
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// Status disc: measured progress with percentage fill, indeterminate ring
/// while unmeasured, calm icons for pending and failure.
class _StatusGlyph extends StatelessWidget {
  final Task task;
  final Color accent;

  const _StatusGlyph({required this.task, required this.accent});

  @override
  Widget build(BuildContext context) {
    switch (task.taskstatus) {
      case TaskStatus.error:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.error_outline, size: 19, color: accent),
        );
      case TaskStatus.running:
        final progress = task.progress;
        return SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.15),
                ),
              ),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.all(DionSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded, size: 13, color: accent),
            ],
          ),
        );
      case TaskStatus.idle:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.schedule, size: 17, color: accent),
        );
    }
  }
}

/// A slim tappable row for bulk actions inside a section.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? DionColors.error : DionColors.primary;
    return Material(
      color: const Color(0x00000000),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tint.withValues(alpha: 0.8)),
              const SizedBox(width: DionSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DionTypography.labelLarge(tint.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DionSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DionColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 32,
              color: DionColors.success,
            ),
          ),
          const SizedBox(height: DionSpacing.lg),
          Text('All caught up', style: context.titleMedium),
          const SizedBox(height: DionSpacing.xs),
          Text(
            'Tasks will appear here while they run.',
            style: DionTypography.bodySmall(context.textSecondary),
          ),
        ],
      ),
    );
  }
}
