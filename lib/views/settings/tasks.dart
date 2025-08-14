import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';

class ActiveTasksSettings extends StatelessWidget {
  const ActiveTasksSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = locate<TaskManager>();
    return NavScaff(
      title: const Text('Active Tasks'),
      child: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final tasks = manager.root
              .traverseBreathFirst()
              .expand((cat) => cat.tasks)
              .toList();
          tasks.sort((a, b) => _statusRank(a).compareTo(_statusRank(b)));

          if (tasks.isEmpty) {
            return SettingTitle(
              title: 'Active Tasks',
              children: [
                Center(
                  child: Text(
                    'No active tasks',
                    style: TextStyle(color: context.theme.disabledColor),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            child: SettingTitle(
              title: 'Active Tasks',
              children: [
                for (final task in tasks)
                  DionBadge(
                    color: context.theme.primaryColor.lighten(5),
                    child: ListenableBuilder(
                      listenable: task,
                      builder: (context, _) {
                        final path = _categoryPath(task.category);
                        return DionListTile(
                          leading: switch (task.taskstatus) {
                            TaskStatus.idle => const Icon(
                              Icons.pending_actions,
                              size: 40,
                            ),
                            TaskStatus.running => DionProgressBar(
                              value: task.progress,
                              type: DionProgressType.linear,
                            ),
                            TaskStatus.error => const Icon(
                              Icons.error,
                              color: Colors.redAccent,
                              size: 40,
                            ),
                          },
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.name, style: context.titleMedium),
                              Text(
                                [
                                  if (path != null) path,
                                  if (task.running) task.status,
                                  if (task.error != null) task.error.toString(),
                                ].whereType<String>().join(' • '),
                                style: context.labelSmall!.copyWith(
                                  color: context.theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                          trailing: switch (task.taskstatus) {
                            TaskStatus.idle => null,
                            TaskStatus.running => DionIconbutton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                task.cancel();
                              },
                            ),
                            TaskStatus.error => DionIconbutton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                task.run();
                              },
                            ),
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static int _statusRank(Task task) => switch (task.taskstatus) {
    TaskStatus.running => 0,
    TaskStatus.error => 1,
    TaskStatus.idle => 2,
  };

  static String? _categoryPath(TaskCategory? category) {
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
}
