import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class SettingDirectory extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<Directory?, dynamic> setting;
  const SettingDirectory({
    super.key,
    required this.title,
    required this.setting,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tile = DionListTile(
      leading: icon != null ? Icon(icon) : null,
      trailing: IconButton(
        onPressed: () {
          getDirectoryPath().then((value) {
            if (value == null) {
              return;
            }
            setting.value = Directory(value);
          });
        },
        icon: const Icon(Icons.folder),
      ),
      title: Text(title, style: context.titleMedium),
    ).paddingAll(5);
    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
