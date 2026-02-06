import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/slider.dart';
import 'package:flutter/material.dart';

/// A slider setting with a clean, scannable layout.
///
/// Shows the title and current value, with a slider below for adjustment.
class SettingSlider<T extends num> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<T, dynamic> setting;
  final T min;
  final T max;
  final T? step;

  const SettingSlider({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.setting,
    required this.min,
    required this.max,
    this.step,
  });

  String _formatValue(T v) {
    if (v is int) return v.toString();
    if (v is double) {
      int precision = 2;
      if (step is double) {
        final s = (step! as double).toString();
        if (s.contains('.')) {
          precision = s.split('.').last.length;
        }
      }
      return v.toStringAsFixed(precision);
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final current = setting.value;
        T local = current;

        final tile = StatefulBuilder(
          builder: (context, setState) => _SettingSliderTile(
            title: title,
            description: description,
            icon: icon,
            valueLabel: _formatValue(local),
            slider: DionSlider<T>(
              value: local,
              min: min,
              max: max,
              onChanged: (p0) => setState(() => local = p0),
              onChangeEnd: (p0) => setting.value = p0,
              step: step,
            ),
          ),
        );

        if (description != null) {
          return Tooltip(message: description!, child: tile);
        }
        return tile;
      },
    );
  }
}

class _SettingSliderTile extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final String valueLabel;
  final Widget slider;

  const _SettingSliderTile({
    required this.title,
    this.description,
    this.icon,
    required this.valueLabel,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row with value
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: context.textSecondary),
                const SizedBox(width: DionSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DionSpacing.sm,
                  vertical: DionSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DionColors.primary.withValues(alpha: 0.1),
                  borderRadius: DionRadius.small,
                ),
                child: Text(
                  valueLabel,
                  style: DionTypography.labelMedium(DionColors.primary),
                ),
              ),
            ],
          ),

          // Slider
          const SizedBox(height: DionSpacing.sm),
          SizedBox(height: 32, child: slider),
        ],
      ),
    );
  }
}
