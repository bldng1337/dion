import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';

class PeriodicJobsSettings extends StatefulWidget {
  const PeriodicJobsSettings({super.key});

  @override
  State<PeriodicJobsSettings> createState() => _PeriodicJobsSettingsState();
}

class _PeriodicJobsSettingsState extends State<PeriodicJobsSettings> {
  final Set<String> _running = {};

  @override
  Widget build(BuildContext context) {
    final service = locate<PeriodicService>();
    final jobs = service.jobs.values.toList();
    return NavScaff(
      title: const Text('Periodic Jobs'),
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Jobs',
            subtitle: 'Scheduled background tasks. Tap to run now.',
            children: [
              if (jobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DionSpacing.lg,
                    vertical: DionSpacing.lg,
                  ),
                  child: Center(
                    child: Text(
                      'No periodic jobs registered',
                      style: DionTypography.bodyMedium(
                        context.theme.disabledColor,
                      ),
                    ),
                  ),
                ),
              for (final job in jobs)
                ListenableBuilder(
                  listenable: Listenable.merge([
                    job.enabledSetting,
                    job.intervalSetting,
                  ]),
                  builder: (context, _) => _JobRow(
                    job: job,
                    service: service,
                    running: _running.contains(job.taskName),
                    onRun: () => _run(job, service),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _run(PeriodicJob job, PeriodicService service) async {
    if (_running.contains(job.taskName)) return;
    setState(() => _running.add(job.taskName));
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final ok = await job.runAndRecord();
      if (!mounted) return;
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ran "${job.displayName}"'
                : 'Failed to run "${job.displayName}"',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _running.remove(job.taskName));
      }
    }
  }
}

class _JobRow extends StatelessWidget {
  final PeriodicJob job;
  final PeriodicService service;
  final bool running;
  final VoidCallback onRun;

  const _JobRow({
    required this.job,
    required this.service,
    required this.running,
    required this.onRun,
  });

  String get _schedule {
    final hours = job.intervalSetting.value;
    return 'Every $hours hour${hours == 1 ? '' : 's'}';
  }

  String _lastRun(JobError? lastError) {
    final last = service.lastRun(job);
    if (last == null) return 'Never run';
    final relative = last.formatrelative();
    if (lastError != null) return 'Last run failed: $relative';
    return 'Last run: $relative';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = job.enabledSetting.value;
    final lastError = service.lastError(job);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 20,
            color: lastError != null
                ? context.theme.colorScheme.error
                : enabled
                    ? context.textSecondary
                    : context.theme.disabledColor,
          ),
          const SizedBox(width: DionSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  job.displayName,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _schedule,
                    if (!enabled) 'Disabled',
                    _lastRun(lastError),
                  ].join(' • '),
                  style: DionTypography.bodySmall(context.textTertiary),
                ),
                if (lastError != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    lastError.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DionTypography.bodySmall(
                      context.theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DionSpacing.md),
          if (running)
            const SizedBox(
              width: 20,
              height: 20,
              child: DionProgressBar(size: 20),
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: 'Run now',
              onPressed: onRun,
            ),
        ],
      ),
    );
  }
}
