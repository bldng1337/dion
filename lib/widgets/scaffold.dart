import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/progress.dart';
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

  void _showJobListPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _JobListPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: locate<TaskManager>(),
      builder: (context, child) {
        final tasks = _getActiveTasks();
        final hasRunningTasks = tasks.any((task) => task.running);
        final hasErrorTasks = tasks.any((task) => task.error != null);

        IconData iconData;
        Color? iconColor;

        if (hasErrorTasks) {
          iconData = Icons.error_outline;
          iconColor = DionColors.error;
        } else if (hasRunningTasks || tasks.isNotEmpty) {
          iconData = Icons.sync;
          iconColor = context.isDarkMode ? DionColors.primary : DionColors.primaryDark;
        } else {
          iconData = Icons.pending_actions_outlined;
          iconColor = context.textSecondary;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showJobListPopup(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(DionSpacing.sm),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                  if (tasks.isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: hasErrorTasks
                              ? DionColors.error
                              : (hasRunningTasks
                                  ? DionColors.primary
                                  : context.textSecondary),
                          borderRadius: BorderRadius.circular(10),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: locate<TaskManager>(),
      builder: (context, child) {
        final tasks = _getActiveTasks();

        return DionDialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(DionSpacing.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.task_alt),
                      const SizedBox(width: DionSpacing.sm),
                      Text(
                        'Active Jobs',
                        style: DionTypography.titleLarge(context.textPrimary),
                      ),
                      const Spacer(),
                      if (tasks.isNotEmpty)
                        Text(
                          '${tasks.length} task${tasks.length != 1 ? 's' : ''}',
                          style: DionTypography.bodySmall(context.textSecondary),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: tasks.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(DionSpacing.xxl),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(height: DionSpacing.md),
                                Text(
                                  'No active jobs',
                                  style: DionTypography.bodyMedium(
                                    context.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: DionSpacing.md,
                          ),
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: DionSpacing.lg),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _TaskListItem(task: task);
                          },
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

class _TaskListItem extends StatelessWidget {
  final Task task;

  const _TaskListItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final hasError = task.error != null;
    final isRunning = task.running;

    return ListenableBuilder(
      listenable: task,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                hasError
                    ? Icons.error_outline
                    : (isRunning ? Icons.sync : Icons.pending),
                size: 20,
                color: hasError
                    ? DionColors.error
                    : (isRunning
                        ? DionColors.primary
                        : context.textSecondary),
              ),
              const SizedBox(width: DionSpacing.sm),
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
                    if (task.status.isNotEmpty || hasError)
                      Text(
                        hasError
                            ? 'Error: ${task.error.toString()}'
                            : task.status,
                        style: DionTypography.bodySmall(
                          hasError ? DionColors.error : context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DionSpacing.sm),
              if (task.progress != null || isRunning)
                SizedBox(
                  width: 60,
                  height: 20,
                  child: DionProgressBar(
                    value: task.progress,
                    type: DionProgressType.linear,
                    color: hasError
                        ? DionColors.error
                        : DionColors.primary,
                  ),
                ),
            ],
          ),
        );
      },
    );
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
