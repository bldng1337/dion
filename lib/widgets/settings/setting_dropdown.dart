import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:flutter/material.dart';

class SettingDropdown<T> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<T, EnumMetaData<T>> setting;
  const SettingDropdown({
    super.key,
    required this.setting,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final items = setting.metadata.values
        .map((e) => DionDropdownItem<T>(label: e.name, value: e.value))
        .toList();

    final tile = ListenableBuilder(
      listenable: setting,
      builder: (context, child) => DionListTile(
        leading: icon != null ? Icon(icon) : null,
        trailing: DionDropdown<T>(
          items: items,
          value: setting.value,
          onChanged: (value) {
            if (value == null) {
              try {
                setting.value = setting.intialValue;
              } catch (_) {}
            } else {
              setting.value = value;
            }
          },
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
