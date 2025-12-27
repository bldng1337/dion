import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
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
        return SettingTileWrapper(
          child: DionListTile(
            leading: icon != null ? Icon(icon) : null,
            subtitle: currentPath != null ? Text(currentPath) : null,
            trailing: DionIconbutton(
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
          ),
        );
      },
    );

    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
