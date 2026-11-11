import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/activity/insights/insight_card.dart';
import 'package:dionysos/views/activity/insights/insight_widgets.dart';
import 'package:flutter/material.dart';

class DevicesData {
  /// Device name to measured time, largest first. Beyond three devices the
  /// rest is folded into an "Other" entry.
  final List<(String name, Duration duration)> devices;
  final int deviceCount;

  const DevicesData({required this.devices, required this.deviceCount});

  Duration get total =>
      devices.fold(Duration.zero, (sum, device) => sum + device.$2);
}

/// How time splits across synced devices in the last 30 days.
class DevicesCard extends InsightCard<DevicesData> {
  const DevicesCard();

  @override
  String get id => 'devices';

  @override
  String get label => 'Across Devices';

  @override
  IconData get icon => Icons.devices;

  @override
  Future<DevicesData?> compute(InsightContext context) async {
    final since = context.now.subtract(const Duration(days: 30));
    final durationById = <String, Duration>{};
    final nameById = <String, String>{};
    for (final activity in context.activitiesSince(since)) {
      final device = activity.device;
      if (device == null) continue;
      durationById[device.deviceId] =
          (durationById[device.deviceId] ?? Duration.zero) + activity.duration;
      // Activities are time-ordered, so the latest name wins after renames.
      if (device.name.trim().isNotEmpty) {
        nameById[device.deviceId] = device.name.trim();
      }
    }
    if (durationById.length < 2) return null;
    final sorted = durationById.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(Duration.zero, (sum, e) => sum + e.value);
    if (total < const Duration(minutes: 30)) return null;

    final shown = [
      for (final (i, entry) in sorted.take(3).indexed)
        (nameById[entry.key] ?? 'Device ${i + 1}', entry.value),
    ];
    final rest = sorted.skip(3).fold(Duration.zero, (sum, e) => sum + e.value);
    return DevicesData(
      devices: [...shown, if (rest > Duration.zero) ('Other', rest)],
      deviceCount: sorted.length,
    );
  }

  @override
  Widget build(BuildContext context, DevicesData data) {
    final scheme = context.theme.colorScheme;
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.onSurfaceVariant,
    ];
    final segments = [
      for (final (i, (name, duration)) in data.devices.indexed)
        Segment(
          label: name,
          duration: duration,
          color: colors[i % colors.length],
        ),
    ];
    final (leader, leaderTime) = data.devices.first;
    final share = (leaderTime.inSeconds / data.total.inSeconds * 100).round();
    return InsightBody(
      top: InsightHero(
        value: '${data.deviceCount}',
        unit: 'devices',
        caption: '$share% on $leader',
        captionLines: 1,
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentBar(segments: segments),
          const SizedBox(height: DionSpacing.sm),
          SegmentLegend(segments: segments),
        ],
      ),
    );
  }
}
