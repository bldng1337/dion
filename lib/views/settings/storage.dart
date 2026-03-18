import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

const archiveVersion = 1;
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
                onTap: () {
                  for (final setting in preferenceCollection.settings) {
                    setting.value = setting.intialValue;
                  }
                },
              ),
            ],
          ),
          const SettingTitle(
            title: 'Storage Usage',
            subtitle: 'Overview of storage used by the app',
            children: [
              _StorageStatsSection(),
            ],
          ),
        ],
      ),
    );
  }
}

class StorageStats {
  final int downloadsCount;
  final int downloadsSize;
  final int cacheSize;
  final int databaseSize;
  final int extensionsSize;
  const StorageStats({
    required this.downloadsCount,
    required this.downloadsSize,
    required this.cacheSize,
    required this.databaseSize,
    required this.extensionsSize,
  });
  int get totalUsed =>
      downloadsSize + cacheSize + databaseSize + extensionsSize;
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

class _StorageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color color;

  const _StorageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceMuted.withValues(alpha: 0.4),
        borderRadius: DionRadius.medium,
        border: Border.all(
          color: context.borderColor.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DionSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: DionRadius.small,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: DionSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: DionTypography.titleMedium(context.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: DionTypography.bodySmall(context.textTertiary),
                  ),
                ],
              ),
            ),
            Text(value, style: DionTypography.titleMedium(color)),
          ],
        ),
      ),
    );
  }
}

class _StorageStatsSection extends StatelessWidget {

  const _StorageStatsSection();

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder(
      future: _calculateStorageStats(),
      loading: (context) => const Padding(
        padding: EdgeInsets.all(DionSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StorageCard(
              icon: Icons.storage_outlined,
              title: 'Total Storage Used',
              subtitle: '',
              value: '...',
              color: DionColors.primary,
            ),
            SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.download_outlined,
              title: 'Downloads',
              subtitle: '',
              value: '...',
              color: DionColors.primary,
            ),
            SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.image_outlined,
              title: 'Image Cache',
              subtitle: 'Cached images and thumbnails',
              value: '...',
              color: DionColors.primary,
            ),
            SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.storage,
              title: 'Database',
              subtitle: 'Library and settings data',
              value: '...',
              color: DionColors.primary,
            ),
            SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.extension_outlined,
              title: 'Extensions',
              subtitle: 'Installed extensions and their data',
              value: '...',
              color: DionColors.primary,
            ),
          ],
        ),
      ),
      builder: (context, value) => Padding(
        padding: const EdgeInsets.all(DionSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StorageCard(
              icon: Icons.storage_outlined,
              title: 'Total Storage Used',
              subtitle: '',
              value: formatBytes(value.totalUsed),
              color: DionColors.primary,
            ),
            const SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.download_outlined,
              title: 'Downloads',
              subtitle:
                  '${value.downloadsCount} episode${value.downloadsCount == 1 ? '' : 's'}',
              value: formatBytes(value.downloadsSize),
              color: DionColors.primary,
            ),
            const SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.image_outlined,
              title: 'Image Cache',
              subtitle: 'Cached images and thumbnails',
              value: formatBytes(value.cacheSize),
              color: DionColors.primary,
            ),
            const SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.storage,
              title: 'Database',
              subtitle: 'Library and settings data',
              value: formatBytes(value.databaseSize),
              color: DionColors.primary,
            ),
            const SizedBox(height: DionSpacing.md),
            _StorageCard(
              icon: Icons.extension_outlined,
              title: 'Extensions',
              subtitle: 'Installed extensions and their data',
              value: formatBytes(value.extensionsSize),
              color: DionColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<StorageStats> _calculateStorageStats() async {
    final dirProvider = await locateAsync<DirectoryProvider>();

    int downloadsCount = 0;
    int downloadsSize = 0;
    try {
      final downloadsDir = dirProvider.downloadspath;
      if (await downloadsDir.exists()) {
        downloadsSize = await getDirectorySize(downloadsDir);

        await for (final entity in downloadsDir.list()) {
          if (entity is Directory) {
            await for (final entryEntity in entity.list()) {
              if (entryEntity is Directory) {
                await for (final episodeEntity in entryEntity.list()) {
                  if (episodeEntity is Directory) {
                    downloadsCount++;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      logger.w('Failed to calculate downloads stats', error: e);
    }

    int cacheSize = 0;
    try {
      final cacheDir = await getTemporaryDirectory();
      final imgCacheDir = cacheDir.sub('imgcache');
      if (await imgCacheDir.exists()) {
        cacheSize = await getDirectorySize(imgCacheDir);
      }
    } catch (e) {
      logger.w('Failed to calculate cache size', error: e);
    }

    int databaseSize = 0;
    try {
      final databaseDir = dirProvider.databasepath;
      if (await databaseDir.exists()) {
        databaseSize = await getDirectorySize(databaseDir);
      }
    } catch (e) {
      logger.w('Failed to calculate database size', error: e);
    }

    int extensionsSize = 0;
    try {
      final extensionsDir = dirProvider.extensionpath;
      if (await extensionsDir.exists()) {
        extensionsSize = await getDirectorySize(extensionsDir);
      }
    } catch (e) {
      logger.w('Failed to calculate extensions size', error: e);
    }

    return StorageStats(
      downloadsCount: downloadsCount,
      downloadsSize: downloadsSize,
      cacheSize: cacheSize,
      databaseSize: databaseSize,
      extensionsSize: extensionsSize,
    );
  }
}
