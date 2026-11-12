import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/release_prediction.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:metis/metis.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const archiveVersion = 3;

const backupExtension = 'dpkg';

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
    // Archives written before the runtime update kept raw source timestamp strings repair them to the ISO form the runtime now strict-parses.
    repairLegacyTimestamps(entry);
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

String _timestamp(DateTime time) =>
    time.toIso8601String().split('.').first.replaceAll(':', '-');

String exportFileName() =>
    'dion-${_timestamp(DateTime.now())}.$backupExtension';

class BackupFile {
  static const _prefix = 'dion-backup-';
  static final _pattern = RegExp(
    r'^dion-backup-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})(?:-(.+))?\.dpkg$',
  );

  final File file;
  final DateTime time;
  final String? label;

  const BackupFile._(this.file, this.time, this.label);

  static BackupFile? parse(File file) {
    final match = _pattern.firstMatch(p.basename(file.path));
    if (match == null) return null;
    final time = DateTime.tryParse(
      '${match[1]}T${match[2]}:${match[3]}:${match[4]}',
    );
    if (time == null) return null;
    return BackupFile._(file, time, match[5]);
  }

  static String fileName(DateTime time, {String? label}) {
    final cleanLabel = label?.replaceAll(RegExp('[^A-Za-z0-9.+_-]'), '');
    final suffix = cleanLabel == null || cleanLabel.isEmpty
        ? ''
        : '-$cleanLabel';
    return '$_prefix${_timestamp(time)}$suffix.$backupExtension';
  }
}

Future<Directory> defaultBackupDirectory() async {
  const folder = kDebugMode || kProfileMode ? 'diondev' : 'dion';
  if (Platform.isAndroid) {
    final appExternal = await getExternalStorageDirectory();
    final path = appExternal?.path;
    final marker = '${p.separator}Android${p.separator}';
    if (path != null && path.contains(marker)) {
      final root = path.substring(0, path.indexOf(marker));
      return Directory(p.join(root, 'Documents', folder, 'backups'));
    }
  }
  return (await getBasePath()).sub('backups');
}

Future<Directory> backupDirectory() async =>
    settings.backup.path.value ?? await defaultBackupDirectory();

Future<List<BackupFile>> listBackups([Directory? directory]) async {
  final dir = directory ?? await backupDirectory();
  if (!await dir.exists()) return [];
  final backups = <BackupFile>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final backup = BackupFile.parse(entity);
    if (backup != null) backups.add(backup);
  }
  backups.sort((a, b) => b.time.compareTo(a.time));
  return backups;
}

int get backupsToKeep => max(1, settings.backup.keep.value);

Duration get autoBackupInterval =>
    Duration(days: max(1, settings.backup.auto.interval.value));

Future<bool> isAutoBackupDue({DateTime? now}) async {
  final latest = (await listBackups()).firstOrNull;
  if (latest == null) return true;
  return (now ?? DateTime.now()).difference(latest.time) >= autoBackupInterval;
}

Future<void> purgeBackups([Directory? directory]) async {
  final dir = directory ?? await backupDirectory();
  final backups = await listBackups(dir);
  for (final backup in backups.skip(backupsToKeep)) {
    try {
      await backup.file.delete();
      logger.i('Purged old backup ${backup.file.path}');
    } catch (e, stack) {
      logger.w(
        'Failed to purge backup ${backup.file.path}',
        error: e,
        stackTrace: stack,
      );
    }
  }
  final staleBefore = DateTime.now().subtract(const Duration(hours: 1));
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (!name.startsWith(BackupFile._prefix) || !name.endsWith(_partSuffix)) {
      continue;
    }
    try {
      if ((await entity.lastModified()).isBefore(staleBefore)) {
        await entity.delete();
      }
    } catch (e) {
      logger.w('Failed to remove partial backup ${entity.path}', error: e);
    }
  }
}

const _partSuffix = '.part';

Future<void> _backupLock = Future.value();

Future<BackupFile> writeBackup({String? label}) {
  final result = _backupLock.then((_) => _writeBackup(label));
  _backupLock = result.then((_) {}, onError: (_) {});
  return result;
}

Future<BackupFile> _writeBackup(String? label) async {
  final dir = await backupDirectory();
  await dir.create(recursive: true);
  final bytes = ZipEncoder().encodeBytes(await createBackup());
  final name = BackupFile.fileName(DateTime.now(), label: label);
  final part = dir.getFile('$name$_partSuffix');
  await part.writeAsBytes(bytes, flush: true);
  final file = await part.rename(dir.getFile(name).path);
  logger.i('Wrote backup ${file.path}');
  await purgeBackups(dir);
  return BackupFile.parse(file)!;
}

class AutoBackupJob extends PeriodicJob {
  @override
  String get taskName => 'autoBackup';

  @override
  String get displayName => 'Automatic backup';

  @override
  Setting<bool, dynamic> get enabledSetting => settings.backup.auto.enabled;

  @override
  Setting<int, dynamic> get intervalSetting => settings.backup.auto.interval;

  @override
  Duration get interval => autoBackupInterval;

  @override
  bool get requiresNetwork => false;

  @override
  Future<void> run(PeriodicJobContext ctx) async {
    // WorkManager runs a newly registered periodic task immediately and may fire inside its flex window, and the app checks on its own while open, so scheduled runs only back up once the interval has really passed.
    if (!ctx.manual && !await isAutoBackupDue()) {
      logger.i('Skipping automatic backup: latest backup is recent enough');
      return;
    }
    ctx.update('Creating backup');
    await writeBackup();
  }
}

class BackupService {
  static const _startupDelay = Duration(seconds: 30);
  static const _checkInterval = Duration(hours: 1);

  final _job = AutoBackupJob();
  bool _checking = false;

  static Future<void> ensureInitialized() async {
    await locateAsync<PreferenceService>();
    await locateAsync<Database>();
    final service = BackupService();
    register<BackupService>(service);
    Timer(_startupDelay, service._runIfDue);
    Timer.periodic(_checkInterval, (_) => service._runIfDue());
    logger.i('Initialised BackupService!');
  }

  Future<void> _runIfDue() async {
    if (_checking || !settings.backup.auto.enabled.value) return;
    _checking = true;
    try {
      if (await isAutoBackupDue()) await _job.runAndRecord();
    } catch (e, stack) {
      logger.e('Automatic backup check failed', error: e, stackTrace: stack);
    } finally {
      _checking = false;
    }
  }
}
