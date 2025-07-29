import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/settings.dart';
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
  const SettingSlider({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.setting,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    var value = setting.value;
    final tile = DionListTile(
      leading: icon != null ? Icon(icon) : null,
      subtitle: ListenableBuilder(
        listenable: setting,
        builder: (context, child) => ListenableBuilder(
          listenable: setting,
          builder: (context, child) => Row(
            children: [
              Text(value.toStringAsPrecision(2)),
              StatefulBuilder(
                builder: (context, setState) => DionSlider<T>(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: (p0) => setState(() => value = p0),
                  onChangeEnd: (p0) => setting.value = p0,
                ),
              ).expanded(),
            ],
          ),
        ),
      ),
      title: Text(title, style: context.titleMedium),
    ).paddingAll(5);
    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
