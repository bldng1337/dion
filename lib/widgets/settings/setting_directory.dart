import 'dart:io';

import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

/// A directory picker setting with the new clean design.
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
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final currentPath = setting.value?.path;

        final tile = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: SettingRow(
            icon: icon,
            title: title,
            subtitle: currentPath,
            control: DionIconbutton(
              tooltip: 'Choose Directory',
              onPressed: () async {
                final value = await getDirectoryPath();
                if (value == null) return;
                try {
                  setting.value = Directory(value);
                } catch (_) {}
              },
              icon: const Icon(Icons.folder_outlined),
            ),
          ),
        );

        if (description != null) {
          return Tooltip(message: description, child: tile);
        }
        return tile;
      },
    );
  }
}
