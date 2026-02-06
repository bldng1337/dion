import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class Storage extends StatelessWidget {
  const Storage({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Backup',
            subtitle: 'Export and import your data',
            children: [
              _StorageAction(
                title: 'Create Backup',
                description: 'Export library to a backup file',
                icon: Icons.backup_outlined,
                onTap: () async {
                  final archive = await createBackup();
                  final String? dir = await getDirectoryPath();
                  if (dir == null) return;
                  final file = File('$dir/dion.dpkg');
                  await file.create(recursive: true);
                  await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
                },
              ),
              _StorageAction(
                title: 'Restore Backup',
                description: 'Import from a backup file',
                icon: Icons.restore_outlined,
                onTap: () async {
                  const XTypeGroup typeGroup = XTypeGroup(
                    label: 'Dion Package',
                    extensions: <String>['dpkg'],
                  );
                  final List<XFile> files = await openFiles(
                    acceptedTypeGroups: <XTypeGroup>[typeGroup],
                  );
                  for (final file in files) {
                    final archive = ZipDecoder().decodeBytes(
                      await file.readAsBytes(),
                    );
                    await applyBackup(archive);
                  }
                },
              ),
            ],
          ),

          SettingTitle(
            title: 'Clear Data',
            subtitle: 'Remove stored data',
            children: [
              _StorageAction(
                title: 'Clear Database',
                description: 'Remove all saved library entries',
                icon: Icons.delete_outline,
                isDestructive: true,
                onTap: () async {
                  await locate<Database>().clear();
                },
              ),
              _StorageAction(
                title: 'Reset Settings',
                description: 'Restore all settings to defaults',
                icon: Icons.settings_backup_restore_outlined,
                isDestructive: true,
                onTap: () async {
                  for (final setting in preferenceCollection.settings) {
                    setting.value = setting.intialValue;
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageAction extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const _StorageAction({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? DionColors.error : DionColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: DionRadius.small,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: DionSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DionTypography.titleSmall(
                        isDestructive ? color : context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: DionTypography.bodySmall(context.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

const archiveVersion = 1;

Future<Archive> createBackup() async {
  final db = locate<Database>();
  final entries = [];
  while (entries.length % 100 == 0) {
    final entriesdb = await db.getEntries(0, 100).toList();
    entries.addAll(entriesdb.map((e) => e.toJson()));
  }
  final archive = Archive();
  archive.addFile(
    ArchiveFile.string(
      'dionmeta.json',
      json.encode({
        'version': archiveVersion,
        'content': ['entries'],
      }),
    ),
  );
  archive.addFile(ArchiveFile.string('entrydata.json', json.encode(entries)));
  return archive;
}

Future<void> applyBackup(Archive archive) async {
  final db = locate<Database>();
  final entries =
      json.decode(
            String.fromCharCodes(archive.findFile('entrydata.json')!.content),
          )
          as List<dynamic>;
  for (final entry in entries) {
    final entrydata = await EntrySaved.fromJson(entry as Map<String, dynamic>);
    await db.updateEntry(entrydata);
  }
}
