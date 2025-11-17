import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/buttons/togglebutton.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:flutter/material.dart';

class SettingToggle extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<bool, dynamic> setting;
  const SettingToggle({
    super.key,
    required this.title,
    required this.setting,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListenableBuilder(
      listenable: setting,
      builder: (context, child) => DionListTile(
        leading: icon != null ? Icon(icon) : null,
        trailing: Togglebutton(
          selected: setting.value,
          onPressed: () => setting.value = !setting.value,
        ),
        title: Text(title, style: context.titleMedium),
      ).paddingAll(5),
    );

    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
