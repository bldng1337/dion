import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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
    final tile = ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final currentPath = setting.value?.path;
        return DionListTile(
          leading: icon != null ? Icon(icon) : null,
          subtitle: currentPath != null ? Text(currentPath) : null,
          trailing: IconButton(
            onPressed: () async {
              final value = await getDirectoryPath();
              if (value == null) return;
              try {
                setting.value = Directory(value);
              } catch (_) {}
            },
            icon: const Icon(Icons.folder),
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
