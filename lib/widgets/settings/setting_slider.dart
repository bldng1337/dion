import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/slider.dart';
import 'package:flutter/material.dart';

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
    final tile = ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final current = setting.value;
        T local = current;
        return DionListTile(
          leading: icon != null ? Icon(icon) : null,
          subtitle: Row(
            children: [
              Text(_formatValue(current)),
              StatefulBuilder(
                builder: (context, setState) => DionSlider<T>(
                  value: local,
                  min: min,
                  max: max,
                  onChanged: (p0) => setState(() => local = p0),
                  onChangeEnd: (p0) => setting.value = p0,
                  step: step,
                ),
              ).expanded(),
            ],
          ),
          title: Text(title, style: context.titleMedium),
        ).paddingAll(5);
      },
    );
    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
