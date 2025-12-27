import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';

class SettingTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget>? children;
  const SettingTitle({
    super.key,
    required this.title,
    this.children,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (children == null) {
      return SettingTileWrapper(
        child: DionListTile(
          leading: icon != null ? Icon(icon) : null,
          title: Text(title, style: context.titleLarge),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingTileWrapper(
          child: DionListTile(
            leading: icon != null ? Icon(icon) : null,
            title: Text(title, style: context.titleLarge),
          ),
        ),
        if (children != null) Column(children: children!).paddingOnly(left: 15),
      ],
    );
  }
}
