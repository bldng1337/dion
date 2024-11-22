import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/popupmenu.dart';
import 'package:flutter/material.dart';

class SettingDropdown<T extends Enum> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<T, EnumMetaData<T>> setting;
  const SettingDropdown(
      {super.key,
      required this.setting,
      required this.title,
      this.description,
      this.icon});

  @override
  Widget build(BuildContext context) {
    final tile = DionListTile(
      leading: icon != null ? Icon(icon) : null,
      trailing: ListenableBuilder(
        listenable: setting,
        builder: (context, child) => DionPopupMenu(
          items: setting.metadata.enumvalues
              .map(
                (e) => DionPopupMenuItem(
                  label: Text(e.name),
                  onTap: () => setting.value = e,
                ),
              )
              .toList(),
          child: Text(setting.value.name),
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
