import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/backup.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/share.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/views/dialog/backup_access.dart';
import 'package:dionysos/views/dialog/directory_picker.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_numberbox.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show ToastKind;

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
                  final fileName = exportFileName();
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
                  final backupDir = await backupDirectory();
                  final List<XFile> files = await openFiles(
                    acceptedTypeGroups: <XTypeGroup>[typeGroup],
                    initialDirectory: await backupDir.exists()
                        ? backupDir.path
                        : null,
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
            title: 'Automatic Backups',
            subtitle:
                'Keep a rotating set of backups in a folder on this device',
            children: [
              const _BackupStatus(),
              SettingToggle(
                title: 'Back Up Periodically',
                description: 'Create a backup every few days',
                setting: settings.backup.auto.enabled,
                confirm: (value) async =>
                    !value || await ensureBackupAccess(context),
              ),
              SettingNumberbox<int>(
                title: 'Interval (days)',
                setting: settings.backup.auto.interval,
              ),
              SettingToggle(
                title: 'Back Up Before Updating',
                description: 'Create a backup before installing an app update',
                setting: settings.backup.beforeUpdate,
                confirm: (value) async =>
                    !value || await ensureBackupAccess(context),
              ),
              SettingNumberbox<int>(
                title: 'Backups to Keep',
                description:
                    'Older backups are deleted whenever a new one is created',
                setting: settings.backup.keep,
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
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Clear Database',
                    message:
                        'Permanently remove your whole library, including '
                        'categories, progress, notes and activity history?',
                    confirmLabel: 'Clear',
                    destructive: true,
                  );
                  if (confirmed) await locate<Database>().clear();
                },
              ),
              _StorageAction(
                title: 'Reset Settings',
                description: 'Restore all settings to defaults',
                icon: Icons.settings_backup_restore_outlined,
                isDestructive: true,
                onTap: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Reset Settings',
                    message: 'Restore all settings to their defaults?',
                    confirmLabel: 'Reset',
                    destructive: true,
                  );
                  if (!confirmed) return;
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

class _BackupStatus extends StatefulWidget {
  const _BackupStatus();

  @override
  State<_BackupStatus> createState() => _BackupStatusState();
}

class _BackupStatusState extends State<_BackupStatus>
    with StateDisposeScopeMixin {
  late Future<(Directory, List<BackupFile>)> _info = _load();

  @override
  void initState() {
    super.initState();
    Observer(
      _reload,
      Listenable.merge([settings.backup.path, settings.backup.keep]),
      callOnInit: false,
    ).disposedBy(scope);
  }

  Future<(Directory, List<BackupFile>)> _load() async {
    final dir = await backupDirectory();
    return (dir, await listBackups(dir));
  }

  void _reload() => safeSetState(() => _info = _load());

  Future<void> _pickFolder(Directory current) async {
    final path = await pickDirectoryPath(
      context,
      write: true,
      initialDirectory: current.path,
    );
    if (path == null) return;
    settings.backup.path.value = Directory(path);
  }

  Future<void> _backupNow() async {
    if (!await ensureBackupAccess(context)) return;
    try {
      await writeBackup();
      showToast('Backup created', ToastKind.success);
    } catch (e, stack) {
      logger.e('Manual backup failed', error: e, stackTrace: stack);
      showToast('Backup failed: $e', ToastKind.error);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingBuilder(
      future: _info,
      loading: (context) => const Padding(
        padding: EdgeInsets.all(DionSpacing.lg),
        child: Center(child: DionProgressBar(size: 20)),
      ),
      builder: (context, info) {
        final (dir, backups) = info;
        final custom = settings.backup.path.value != null;
        final latest = backups.firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DionSpacing.lg,
                vertical: DionSpacing.md,
              ),
              child: SettingRow(
                icon: Icons.folder_outlined,
                title: custom ? 'Backup Folder' : 'Backup Folder (default)',
                subtitle: dir.path,
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (custom)
                      DionIconbutton(
                        tooltip: 'Use Default Folder',
                        onPressed: () => settings.backup.path.value = null,
                        icon: const Icon(Icons.restart_alt),
                      ),
                    DionIconbutton(
                      tooltip: 'Choose Folder',
                      onPressed: () => _pickFolder(dir),
                      icon: const Icon(Icons.drive_folder_upload_outlined),
                    ),
                  ],
                ),
              ),
            ),
            _StorageAction(
              title: 'Back Up Now',
              description: latest == null
                  ? 'No backups in this folder yet'
                  : 'Last backup ${latest.time.formatrelative()} • '
                        '${backups.length} of $backupsToKeep kept',
              icon: Icons.save_outlined,
              onTap: _backupNow,
            ),
          ],
        );
      },
    );
  }
}
