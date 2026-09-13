import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/utils/background_policy.dart';
import 'package:dionysos/utils/connectivity.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

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
            title: 'Conditions',
            subtitle:
                'When jobs and the automatic update check may run. Manual runs are never held back.',
            children: [
              const _ConditionsStatus(),
              SettingToggle(
                title: 'Only on unmetered networks',
                description:
                    'Wait for Wi-Fi or Ethernet instead of running on mobile data',
                setting: settings.background.unmeteredOnly,
              ),
              SettingToggle(
                title: 'Only while plugged in',
                description: 'Wait until the device is connected to power',
                setting: settings.background.chargingOnly,
              ),
              SettingToggle(
                title: 'Skip on low battery',
                description: 'Postpone work while the battery is at 15% or less',
                setting: settings.background.batteryNotLow,
              ),
            ],
          ),
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

/// Live preview of the background conditions: polls the current network and
/// power state so the user can see which rules hold and which hold work back.
class _ConditionsStatus extends StatefulWidget {
  const _ConditionsStatus();

  @override
  State<_ConditionsStatus> createState() => _ConditionsStatusState();
}

class _ConditionsStatusState extends State<_ConditionsStatus>
    with StateDisposeScopeMixin {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _poll;
  BackgroundEvaluation? _evaluation;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());
    // Re-evaluate as soon as a rule is toggled rather than at the next poll.
    Observer(
      _refresh,
      Listenable.merge([
        settings.background.unmeteredOnly,
        settings.background.chargingOnly,
        settings.background.batteryNotLow,
      ]),
      callOnInit: false,
    ).disposedBy(scope);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final evaluation = await BackgroundPolicy.evaluate();
    safeSetState(() => _evaluation = evaluation);
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _evaluation;
    if (evaluation == null) {
      return const Padding(
        padding: EdgeInsets.all(DionSpacing.lg),
        child: Center(child: DionProgressBar(size: 20)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DionSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RuleRow(
            icon: evaluation.allowed
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: evaluation.allowed
                ? DionColors.primary
                : context.theme.colorScheme.error,
            label: evaluation.allowed
                ? 'Background work is allowed right now'
                : 'Waiting for ${_waitingFor(evaluation)}',
          ),
          _RuleRow(
            icon: _statusIcon(evaluation.unmeteredRule),
            color: _statusColor(context, evaluation.unmeteredRule),
            label: 'Only on unmetered networks',
            measurement: switch (evaluation.network) {
              NetworkClass.unmetered => 'On an unmetered connection',
              NetworkClass.metered => 'On a metered connection',
              NetworkClass.none => 'No network connection',
            },
          ),
          _RuleRow(
            icon: _statusIcon(evaluation.chargingRule),
            color: _statusColor(context, evaluation.chargingRule),
            label: 'Only while plugged in',
            measurement: _chargingMeasurement(evaluation),
          ),
          _RuleRow(
            icon: _statusIcon(evaluation.batteryRule),
            color: _statusColor(context, evaluation.batteryRule),
            label: 'Skip on low battery',
            measurement: _batteryMeasurement(evaluation),
          ),
        ],
      ),
    );
  }

  String _waitingFor(BackgroundEvaluation evaluation) {
    return [
      if (evaluation.unmeteredRule == RuleStatus.blocked)
        _unmeteredWaiting(evaluation.network),
      if (evaluation.chargingRule == RuleStatus.blocked) 'power',
      if (evaluation.batteryRule == RuleStatus.blocked) 'a battery above 15%',
    ].join(', ');
  }

  String _unmeteredWaiting(NetworkClass network) =>
      network == NetworkClass.none
      ? 'a network connection'
      : 'an unmetered network';

  String _chargingMeasurement(BackgroundEvaluation evaluation) {
    if (evaluation.pluggedIn) return 'Plugged in';
    final level = evaluation.batteryLevel;
    return level != null ? 'On battery ($level%)' : 'On battery';
  }

  String _batteryMeasurement(BackgroundEvaluation evaluation) {
    final level = evaluation.batteryLevel;
    return level == null ? 'No battery detected' : 'Battery at $level%';
  }

  IconData _statusIcon(RuleStatus status) => switch (status) {
    RuleStatus.passed => Icons.check_circle_outline,
    RuleStatus.blocked => Icons.error_outline,
    RuleStatus.off => Icons.remove_circle_outline,
  };

  Color _statusColor(BuildContext context, RuleStatus status) =>
      switch (status) {
        RuleStatus.passed => DionColors.primary,
        RuleStatus.blocked => context.theme.colorScheme.error,
        RuleStatus.off => context.textTertiary,
      };
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? measurement;

  const _RuleRow({
    required this.icon,
    required this.color,
    required this.label,
    this.measurement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: DionSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
                if (measurement != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    measurement!,
                    style: DionTypography.bodySmall(context.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
