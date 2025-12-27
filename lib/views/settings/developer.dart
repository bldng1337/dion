import 'dart:math';

import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class DebugTask extends Task {
  bool canceled = false;

  DebugTask(super.name);
  @override
  Future<void> onCancel() async {
    canceled = true;
  }

  @override
  Future<void> onRun() async {
    const max = 100;
    for (int i = 0; i < max; i++) {
      progress = i / max;
      status = 'Running $i';
      if (canceled) break;
      await Future.delayed(const Duration(milliseconds: 20));
    }
    if (Random().nextBool()) {
      throw Exception('Random Test Exception');
    }
  }
}

class DeveloperSettings extends StatelessWidget {
  const DeveloperSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Developer Settings'),
      child: ListView(
        children: [
          SettingTitle(
            title: 'Debug Button',
            children: [
              DionListTile(
                title: const Text('Start Random Task'),
                onTap: () {
                  final task = DebugTask('Test${Random().nextInt(10000)}');
                  final manager = locate<TaskManager>();
                  manager.root
                      .createOrGetCategory('dev', 'Test', concurrency: 3)
                      .enqueue(task);
                },
              ),
              DionListTile(
                title: const Text('Add Random Logs'),
                onTap: () {
                  logger.i('Info');
                  logger.d('Debug');
                  logger.w('Warning');
                  logger.e(
                    'Error',
                    error: Exception('Error'),
                    stackTrace: StackTrace.current,
                  );
                  logger.f('Fatal');
                },
              ),
            ],
          ),
          DionListTile(
            title: const Text('Logs'),
            subtitle: const Text('Logs'),
            onTap: () {
              context.push('/dev/logs');
            },
          ),
          DionListTile(
            title: const Text('Widget Playground'),
            subtitle: const Text('Showcase and test widgets'),
            onTap: () {
              context.push('/dev/widgets');
            },
          ),
        ],
      ),
    );
  }
}
