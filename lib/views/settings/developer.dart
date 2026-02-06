import 'dart:math';

import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart' show Icons, Material, InkWell;
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
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Debug Actions',
            subtitle: 'Testing and debugging tools',
            children: [
              _DevAction(
                title: 'Start Random Task',
                description: 'Queue a test task for debugging',
                icon: Icons.play_circle_outline,
                onTap: () {
                  final task = DebugTask('Test${Random().nextInt(10000)}');
                  final manager = locate<TaskManager>();
                  manager.root
                      .createOrGetCategory('dev', 'Test', concurrency: 3)
                      .enqueue(task);
                },
              ),
              _DevAction(
                title: 'Add Random Logs',
                description: 'Generate test log entries',
                icon: Icons.note_add_outlined,
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

          SettingTitle(
            title: 'Tools',
            subtitle: 'Development utilities',
            children: [
              _DevAction(
                title: 'Logs',
                description: 'View application logs',
                icon: Icons.article_outlined,
                onTap: () => context.push('/dev/logs'),
              ),
              _DevAction(
                title: 'Widget Playground',
                description: 'Showcase and test widgets',
                icon: Icons.widgets_outlined,
                onTap: () => context.push('/dev/widgets'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevAction extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _DevAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DionColors.primary.withValues(alpha: 0.1),
                  borderRadius: DionRadius.small,
                ),
                child: Icon(icon, size: 18, color: DionColors.primary),
              ),
              const SizedBox(width: DionSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DionTypography.titleSmall(context.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: DionTypography.bodySmall(context.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
