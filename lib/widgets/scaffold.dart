import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Destination {
  final IconData ico;
  final String name;
  final String path;
  Destination({required this.ico, required this.name, required this.path});
}

class _JobIndicator extends StatelessWidget {
  const _JobIndicator();

  List<Task> _getActiveTasks() {
    final taskManager = locate<TaskManager>();
    return taskManager.root
        .traverseBreathFirst()
        .expand((cat) => cat.tasks)
        .where((task) => !task.finished)
        .toList();
  }

  double? _overallProgress(List<Task> tasks) {
    final measured = tasks
        .where((task) => task.running && task.progress != null)
        .map((task) => task.progress!)
        .toList();
    if (measured.isEmpty) return null;
    return measured.fold<double>(0, (a, b) => a + b) / measured.length;
  }

  void _showJobListPopup(BuildContext context) {
    showDialog(context: context, builder: (context) => const _JobListPopup());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: locate<TaskManager>(),
      builder: (context, child) {
        final tasks = _getActiveTasks();
        final runningCount = tasks.where((task) => task.running).length;
        final errorCount = tasks.where((task) => task.error != null).length;
        final hasRunning = runningCount > 0;
        final hasError = errorCount > 0;

        final primaryAccent = context.isDarkMode
            ? DionColors.primary
            : DionColors.primaryDark;
        final Color accent = hasError
            ? DionColors.error
            : (hasRunning ? primaryAccent : context.textTertiary);
        final progress = _overallProgress(tasks);

        final String tooltip = tasks.isEmpty
            ? 'No active tasks'
            : hasError
            ? '$errorCount failed · ${tasks.length} total'
            : hasRunning
            ? '$runningCount running · ${tasks.length} total'
            : '${tasks.length} queued';

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 500),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showJobListPopup(context),
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Tinted background disc.
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: tasks.isEmpty ? 0.06 : 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Progress ring around the button.
                    if (hasRunning)
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2.5,
                          strokeCap: StrokeCap.round,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: 0.15),
                        ),
                      ),
                    Icon(Icons.checklist_rounded, size: 18, color: accent),
                    if (tasks.isNotEmpty)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            tasks.length.toString(),
                            style: DionTypography.labelSmall(Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobListPopup extends StatelessWidget {
  const _JobListPopup();

  List<Task> _getActiveTasks() {
    final taskManager = locate<TaskManager>();
    return taskManager.root
        .traverseBreathFirst()
        .expand((cat) => cat.tasks)
        .where((task) => !task.finished)
        .toList();
  }

  double? _overallProgress(List<Task> tasks) {
    final measured = tasks
        .where((task) => task.running && task.progress != null)
        .map((task) => task.progress!)
        .toList();
    if (measured.isEmpty) return null;
    return measured.fold<double>(0, (a, b) => a + b) / measured.length;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: locate<TaskManager>(),
      builder: (context, child) {
        final tasks = _getActiveTasks();
        final runningCount = tasks.where((task) => task.running).length;
        final errorCount = tasks.where((task) => task.error != null).length;
        final hasRunning = runningCount > 0;
        final hasError = errorCount > 0;

        final primaryAccent = context.isDarkMode
            ? DionColors.primary
            : DionColors.primaryDark;
        final Color accent = hasError
            ? DionColors.error
            : (hasRunning ? primaryAccent : context.textTertiary);
        final progress = _overallProgress(tasks);

        final String subtitle = tasks.isEmpty
            ? 'Nothing running'
            : hasError
            ? '$errorCount failed · ${tasks.length} total'
            : hasRunning
            ? '$runningCount running · ${tasks.length} total'
            : '${tasks.length} queued';

        return DionDialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DionSpacing.lg,
                    DionSpacing.lg,
                    DionSpacing.sm,
                    DionSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.checklist_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: DionSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tasks',
                              style: DionTypography.titleMedium(
                                context.textPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: DionTypography.bodySmall(
                                context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                if (hasRunning)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DionSpacing.lg,
                      0,
                      DionSpacing.lg,
                      DionSpacing.md,
                    ),
                    child: ClipRRect(
                      borderRadius: DionRadius.small,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Flexible(
                  child: tasks.isEmpty
                      ? const _JobEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: DionSpacing.sm,
                          ),
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: DionSpacing.lg,
                            endIndent: DionSpacing.lg,
                            color: context.dionDivider,
                          ),
                          itemBuilder: (context, index) =>
                              _TaskListItem(task: tasks[index]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JobEmptyState extends StatelessWidget {
  const _JobEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.xxl,
        vertical: DionSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DionColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 30,
              color: DionColors.success,
            ),
          ),
          const SizedBox(height: DionSpacing.md),
          Text(
            'All caught up',
            style: DionTypography.titleSmall(context.textPrimary),
          ),
          const SizedBox(height: DionSpacing.xs),
          Text(
            'No active tasks right now',
            style: DionTypography.bodySmall(context.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final Task task;

  const _TaskListItem({required this.task});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: task,
      builder: (context, child) {
        final hasError = task.error != null;
        final isRunning = task.running;
        final hasProgress = task.progress != null;

        final primaryAccent = context.isDarkMode
            ? DionColors.primary
            : DionColors.primaryDark;
        final Color accent = hasError
            ? DionColors.error
            : (isRunning ? primaryAccent : context.textTertiary);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: _TaskStatusGlyph(
                  hasError: hasError,
                  isRunning: isRunning,
                  hasProgress: hasProgress,
                  progress: task.progress,
                  accent: accent,
                ),
              ),
              const SizedBox(width: DionSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.name,
                      style: DionTypography.bodyMedium(context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (task.status.isNotEmpty || hasError) ...[
                      const SizedBox(height: 2),
                      Text(
                        hasError ? task.error.toString() : task.status,
                        style: DionTypography.bodySmall(
                          hasError ? DionColors.error : context.textSecondary,
                        ),
                        maxLines: hasError ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isRunning)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Cancel task',
                  visualDensity: VisualDensity.compact,
                  color: context.textTertiary,
                  onPressed: task.cancel,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskStatusGlyph extends StatelessWidget {
  final bool hasError;
  final bool isRunning;
  final bool hasProgress;
  final double? progress;
  final Color accent;

  const _TaskStatusGlyph({
    required this.hasError,
    required this.isRunning,
    required this.hasProgress,
    required this.progress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Icon(Icons.error_outline, size: 22, color: accent);
    }
    if (isRunning) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: hasProgress ? progress : null,
              strokeWidth: 2,
              strokeCap: StrokeCap.round,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.15),
            ),
          ),
          Icon(Icons.play_arrow, size: 9, color: accent),
        ],
      );
    }
    return Icon(Icons.hourglass_empty, size: 20, color: accent);
  }
}

class NavScaff extends StatelessWidget {
  final Widget child;
  final List<Destination> destination;
  final List<Widget>? actions;
  final Widget? title;
  final Widget? floatingActionButton;
  final bool showNavbar;

  const NavScaff({
    super.key,
    required this.child,
    this.destination = const [],
    this.actions,
    this.title,
    this.floatingActionButton,
    this.showNavbar = true,
  });

  Widget bottomNavBar(BuildContext context, int index) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
        floatingActionButton: floatingActionButton,
        appBar: showNavbar ? AppBar(title: title, actions: actions) : null,
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: context.dividerColor, width: 0.5),
            ),
          ),
          child: NavigationBar(
            height: 60,
            backgroundColor: context.theme.scaffoldBackgroundColor,
            selectedIndex: index >= 0 ? index : 0,
            destinations: destination
                .map(
                  (e) =>
                      NavigationDestination(icon: Icon(e.ico), label: e.name),
                )
                .toList(),
            onDestinationSelected: (i) => context.go(destination[i].path),
          ),
        ),
      ),
      DionThemeMode.cupertino => CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: index >= 0 ? index : 0,
          items: destination
              .map(
                (e) =>
                    BottomNavigationBarItem(icon: Icon(e.ico), label: e.name),
              )
              .toList(),
          onTap: (i) => context.go(destination[i].path),
        ),
        tabBuilder: (context, index) => CupertinoTabView(
          builder: (context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: title,
              trailing: Row(children: actions ?? []),
            ),
            child: child.paddingOnly(top: 45),
          ),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final int index = destination.indexWhere(
      (element) =>
          GoRouterState.of(context).fullPath?.startsWith(element.path) ?? false,
    );
    if (!context.showNavbar && destination.length > 1) {
      return bottomNavBar(context, index);
    }
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
        floatingActionButton: floatingActionButton,
        body: GestureDetector(
          onTap: ContextMenuController.removeAny,
          child: Row(
            children: [
              if (destination.length > 1)
                LayoutBuilder(
                  builder: (context, constraint) {
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraint.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: context.dionDivider,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: NavigationRail(
                                trailing: const _JobIndicator(),
                                onDestinationSelected: (i) =>
                                    context.go(destination[i].path),
                                labelType: NavigationRailLabelType.all,
                                minWidth: 72,
                                destinations: destination
                                    .map(
                                      (e) => NavigationRailDestination(
                                        icon: Icon(e.ico),
                                        label: Text(e.name),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: DionSpacing.xs,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                selectedIndex: index >= 0 ? index : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Expanded(child: child),
            ],
          ),
        ),

        appBar: showNavbar
            ? AppBar(
                toolbarHeight: 50,
                leadingWidth: 50,
                titleSpacing: 0,
                title: title,
                actions: actions,
                leading: destination.isEmpty ? null : nil,
              )
            : null,
      ),
      DionThemeMode.cupertino => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: title,
          trailing: Row(
            children: [const Spacer(), if (actions != null) ...actions!],
          ),
        ),
        child: Row(
          children: [
            if (destination.length > 1)
              Container(
                width: 130,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: context.dividerColor, width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: destination
                      .map(
                        (e) => CupertinoButton(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(e.ico).paddingAll(5),
                              Text(e.name).expanded(),
                            ],
                          ),
                          onPressed: () => context.go(e.path),
                        ),
                      )
                      .toList(),
                ),
              ),
            child.expanded(),
          ],
        ).paddingOnly(top: 45),
      ),
    };
  }
}
