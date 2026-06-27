import 'dart:math';

import 'package:dionysos/data/activity/fake_activity.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart'
    show AlertDialog, Icons, InkWell, Material, TextButton, showDialog;
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
              _DevAction(
                title: 'Generate Fake Activity',
                description:
                    'Create ~1 year of randomized activity for library entries',
                icon: Icons.timeline_outlined,
                onTap: () => _confirmGenerateFakeActivity(context),
              ),
              _DevAction(
                title: 'Clear Activity Data',
                description: 'Delete all activity records',
                icon: Icons.delete_sweep_outlined,
                isDestructive: true,
                onTap: () => _confirmClearActivity(context),
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
  final bool isDestructive;

  const _DevAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? DionColors.error : DionColors.primary;
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
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: DionRadius.small,
                ),
                child: Icon(icon, size: 18, color: accent),
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

Future<bool> _confirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: DionColors.error)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void _confirmGenerateFakeActivity(BuildContext context) {
  _confirmDialog(
    context: context,
    title: 'Generate fake activity?',
    message:
        'Creates randomized activity events spread across roughly the past '
        'year for every entry in your library. Existing activity is kept. '
        'This runs as a background task and can be cancelled.',
    confirmLabel: 'Generate',
  ).then((confirmed) {
    if (!confirmed) return;
    final task = GenerateFakeActivityTask();
    final manager = locate<TaskManager>();
    manager.root
        .createOrGetCategory('dev', 'Test', concurrency: 3)
        .enqueue(task);
  });
}

void _confirmClearActivity(BuildContext context) {
  _confirmDialog(
    context: context,
    title: 'Clear all activity?',
    message:
        'Permanently deletes every activity record. Library entries and '
        'categories are not affected. This cannot be undone.',
    confirmLabel: 'Clear',
    destructive: true,
  ).then((confirmed) async {
    if (!confirmed) return;
    try {
      await locate<Database>().clearActivities();
    } catch (e, stack) {
      logger.e('Failed to clear activity', error: e, stackTrace: stack);
    }
  });
}
