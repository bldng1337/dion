import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/share.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:metis/metis.dart';
import 'package:path_provider/path_provider.dart';

const archiveVersion = 3;

Map<String, dynamic> _readJsonMap(Archive archive, String name) =>
    json.decode(utf8.decode(archive.findFile(name)!.content))
        as Map<String, dynamic>;

List<dynamic> _readJsonList(Archive archive, String name) =>
    json.decode(utf8.decode(archive.findFile(name)!.content)) as List<dynamic>;

// The settings tree is a lazy top-level final; referencing it builds every
// preference-backed Setting and registers it in preferenceCollection.
void _ensureSettingsBuilt() => settings.toString();

Future<void> applyBackup(Archive archive) async {
  final db = locate<Database>();
  final meta = _readJsonMap(archive, 'dionmeta.json');
  final categoriesByName = {
    for (final category in await db.getCategories()) category.name: category,
  };
  switch (meta['version'] as int) {
    case 1:
      await _restoreEntries(archive, db, categoriesByName);
    case 2:
      // V2 backups carry no category definitions; entry-referenced names are
      // recreated instead of being silently dropped.
      await _restoreEntries(archive, db, categoriesByName);
      await _restoreActivities(archive, db);
    case 3:
      await _restoreCategories(archive, db, categoriesByName);
      await _restoreEntries(archive, db, categoriesByName);
      await _restoreActivities(archive, db);
      await _restoreExtensions(archive, db);
      _ensureSettingsBuilt();
      await _restoreSettings(archive);
    default:
      logger.w('Unknown backup version: ${meta['version']}');
      return;
  }
}

/// Restores category definitions before entries so entry references resolve.
/// A locally existing category with the same name keeps its record id
/// (entries resolve by name) but adopts the backup's sort order.
Future<void> _restoreCategories(
  Archive archive,
  Database db,
  Map<String, Category> categoriesByName,
) async {
  for (final raw in _readJsonList(archive, 'categorydata.json')) {
    final json = Map<String, dynamic>.from(raw as Map);
    json['id'] = DBRecord.fromJson(json['id'] as Map<String, dynamic>);
    final category = Category.fromJson(json);
    final existing = categoriesByName[category.name];
    if (existing == null) {
      await db.updateCategory(category);
      categoriesByName[category.name] = category;
    } else if (existing.index != category.index) {
      final updated = existing.copyWith(index: category.index);
      await db.updateCategory(updated);
      categoriesByName[category.name] = updated;
    }
  }
}

/// Resolves an entry's serialized categories to [Category] objects, creating
/// missing ones. V1 backups stored record references, later versions store
/// names; both are matched against local categories by name.
Future<List<Category>> _resolveEntryCategories(
  Database db,
  dynamic raw,
  Map<String, Category> categoriesByName,
) async {
  if (raw is! List) return [];
  final categories = <Category>[];
  for (final item in raw) {
    if (item is Map) {
      final json = Map<String, dynamic>.from(item);
      json['id'] = DBRecord.fromJson(json['id'] as Map<String, dynamic>);
      final category = Category.fromJson(json);
      final resolved = categoriesByName.putIfAbsent(
        category.name,
        () => category,
      );
      if (identical(resolved, category)) {
        await db.updateCategory(category);
      }
      categories.add(resolved);
    } else if (item is String) {
      var category = categoriesByName[item];
      if (category == null) {
        category = Category.construct(item, categoriesByName.length);
        await db.updateCategory(category);
        categoriesByName[item] = category;
      }
      categories.add(category);
    }
  }
  return categories;
}

Future<void> _restoreEntries(
  Archive archive,
  Database db,
  Map<String, Category> categoriesByName,
) async {
  for (final raw in _readJsonList(archive, 'entrydata.json')) {
    final entry = Map<String, dynamic>.from(raw as Map);
    entry['categories'] = await _resolveEntryCategories(
      db,
      entry['categories'],
      categoriesByName,
    );
    final entryData = await EntrySaved.fromJson(entry);
    await db.updateEntry(entryData);
  }
}

Future<void> _restoreActivities(Archive archive, Database db) async {
  for (final raw in _readJsonList(archive, 'activitydata.json')) {
    final activity = Map<String, dynamic>.from(raw as Map);
    activity['time'] = DateTime.parse(activity['time'] as String);
    await db.addActivity(Activity.fromJson(activity));
  }
}

Future<void> _restoreExtensions(Archive archive, Database db) async {
  for (final raw in _readJsonList(archive, 'extensiondata.json')) {
    final json = Map<String, dynamic>.from(raw as Map);
    json['id'] = DBRecord.fromJson(json['id'] as Map<String, dynamic>);
    await db.setExtensionMetaData(ExtensionMetaData.fromJson(json));
  }
}

/// Applies backed-up setting values to the live settings; each Setting's
/// onChange persists the value. Directory settings are skipped: absolute
/// paths do not transfer between devices or platforms.
Future<void> _restoreSettings(Archive archive) async {
  final data = _readJsonMap(archive, 'settingsdata.json');
  final settingsById = {
    for (final setting in preferenceCollection.settings)
      setting.metadata.id: setting,
  };
  for (final MapEntry(:key, :value) in data.entries) {
    final setting = settingsById[key];
    if (setting == null) continue;
    final parsed = setting.metadata.parse(value as String);
    if (parsed != null) setting.value = parsed;
  }
}

Future<Archive> createBackup() async {
  final db = locate<Database>();
  _ensureSettingsBuilt();
  final archive = Archive();
  final entries = [];
  int ind = 0;
  while (entries.length % 100 == 0) {
    // If we don't get 100 entries, we are at the end
    final entriesdb = await db.getEntries(ind++, 100).toList();
    if (entriesdb.isEmpty) break;
    entries.addAll(
      entriesdb.map((e) {
        final json = e.toJson();
        json['categories'] = e.categories.map((c) => c.name).toList();
        return json;
      }),
    );
  }
  archive.addFile(ArchiveFile.string('entrydata.json', json.encode(entries)));
  archive.addFile(
    ArchiveFile.string(
      'categorydata.json',
      json.encode((await db.getCategories()).map((c) => c.toJson()).toList()),
    ),
  );
  final activities = [];
  int actInd = 0;
  while (activities.length % 100 == 0) {
    final activitiesdb = await db.getActivities(actInd++, 100).toList();
    if (activitiesdb.isEmpty) break;
    activities.addAll(
      activitiesdb.map((e) {
        final json = e.toDBJson();
        json['time'] = (json['time'] as DateTime).toIso8601String(); // Maybe we should do something that is robuster to schema changes here
        return json;
      }),
    );
  }
  archive.addFile(
    ArchiveFile.string('activitydata.json', json.encode(activities)),
  );
  archive.addFile(
    ArchiveFile.string(
      'extensiondata.json',
      json.encode(
        (await db.getExtensionsMetadata()).map((e) => e.toDBJson()).toList(),
      ),
    ),
  );
  final settingsData = <String, String>{};
  for (final setting in preferenceCollection.settings) {
    final metadata = setting.metadata;
    if (metadata is PreferenceDirectoryMetaData) continue;
    settingsData[metadata.id] = metadata.stringify(setting.value);
  }
  archive.addFile(
    ArchiveFile.string('settingsdata.json', json.encode(settingsData)),
  );
  archive.addFile(
    ArchiveFile.string(
      'dionmeta.json',
      json.encode({
        'version': archiveVersion,
        'content': [
          'entries',
          'categories',
          'activities',
          'extensions',
          'settings',
        ],
      }),
    ),
  );
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
            title: 'Downloads',
            subtitle: 'Review and free up downloaded episodes',
            children: [
              _StorageAction(
                title: 'Manage Downloads',
                description: 'See downloaded episodes and their disk usage',
                icon: Icons.download_outlined,
                onTap: () {
                  context.push('/settings/downloads');
                },
              ),
            ],
          ),
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
                  final fileName =
                      'dion-${DateTime.now().toIso8601String().replaceAll(':', '-')}.dpkg';
                  if (getPlatform() == CPlatform.ios ||
                      getPlatform() == CPlatform.android) {
                    final dir = await getTemporaryDirectory();
                    final file = File('${dir.path}/$fileName');
                    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
                    await shareFiles([file]);
                  } else {
                    final String? dir = await getDirectoryPath();
                    if (dir == null) return;
                    final file = File('$dir/$fileName');
                    await file.create(recursive: true);
                    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
                  }
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
            title: 'Auto-Download',
            subtitle: 'Keep permanent copies of images in case sources go down',
            children: [
              SettingToggle(
                title: 'Entry Covers & Posters',
                description: 'Stored when an entry is saved to the library',
                setting: settings.autoDownload.entryCovers,
              ),
              SettingToggle(
                title: 'Quote Images',
                description: 'Stored when an image is saved as a quote',
                setting: settings.autoDownload.quoteImages,
              ),
              SettingToggle(
                title: 'Extension Icons',
                description: 'Stored when an extension is installed',
                setting: settings.autoDownload.extensionIcons,
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
            children: [_StorageStatsSection()],
          ),
        ],
      ),
    );
  }
}

class StorageStats {
  final int downloadsCount;
  final int downloadsSize;
  final int imageStoreCount;
  final int imageStoreSize;
  final int cacheSize;
  final int databaseSize;
  final int extensionsSize;
  const StorageStats({
    required this.downloadsCount,
    required this.downloadsSize,
    required this.imageStoreCount,
    required this.imageStoreSize,
    required this.cacheSize,
    required this.databaseSize,
    required this.extensionsSize,
  });
  int get totalUsed =>
      downloadsSize +
      imageStoreSize +
      cacheSize +
      databaseSize +
      extensionsSize;
}

class _StorageAction extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  // ignore: avoid_futureor_void
  final FutureOr<void> Function() onTap;
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
      child: Loadable(
        loading: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.3,
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
                            style: DionTypography.bodySmall(
                              context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const DionProgressBar(size: 16),
          ],
        ),
        builder: (context, child, setFuture) => InkWell(
          onTap: () {
            setFuture(onTap.call());
          },
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
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.textTertiary,
                ),
              ],
            ),
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
              icon: Icons.collections_outlined,
              title: 'Stored Images',
              subtitle: 'Automatically kept covers, quotes and icons',
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
      builder: (context, value) {
        final imageStoreCount = value.imageStoreCount;
        return Padding(
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
                icon: Icons.collections_outlined,
                title: 'Stored Images',
                subtitle:
                    '$imageStoreCount image${imageStoreCount == 1 ? '' : 's'} automatically kept',
                value: formatBytes(value.imageStoreSize),
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
        );
      },
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

    int imageStoreCount = 0;
    int imageStoreSize = 0;
    try {
      final imageDir = dirProvider.imagepath;
      if (await imageDir.exists()) {
        imageStoreSize = await getDirectorySize(imageDir);
        await for (final entity in imageDir.list()) {
          if (entity is File) {
            imageStoreCount++;
          }
        }
      }
    } catch (e) {
      logger.w('Failed to calculate stored images stats', error: e);
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
      imageStoreCount: imageStoreCount,
      imageStoreSize: imageStoreSize,
      cacheSize: cacheSize,
      databaseSize: databaseSize,
      extensionsSize: extensionsSize,
    );
  }
}
