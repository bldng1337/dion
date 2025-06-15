import 'dart:convert';

import 'package:dionysos/data/activity.dart';
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_surrealdb/flutter_surrealdb.dart';
import 'package:metis/metis.dart';

class ExtensionMetaData {
  final String id;
  final bool enabled;
  const ExtensionMetaData(this.id, this.enabled);

  @override
  String toString() {
    return 'ExtensionMetaData{id: $id, enabled: $enabled}';
  }

  ExtensionMetaData copyWith({
    String? id,
    bool? enabled,
  }) {
    return ExtensionMetaData(
      id ?? this.id,
      enabled ?? this.enabled,
    );
  }
}

abstract class Database extends ChangeNotifier {
  Future<void> init();

  Future<void> merge(String path);

  Future<ExtensionMetaData> getExtensionMetaData(ExtensionData extdata);
  Future<void> setExtensionMetaData(
    Extension extension,
    ExtensionMetaData data,
  );

  Stream<EntrySaved> getEntries(int page, int limit);
  Stream<EntrySaved> getEntriesSQL(
    String sqlfilter,
    Map<String, dynamic>? vars,
  );
  Future<EntrySaved?> isSaved(Entry entry);
  Future<EntrySaved?> getEntry(String id, Extension extension);
  Future<void> removeEntry(EntryDetailed entry);
  Future<void> updateEntry(EntryDetailed entry);
  Future<void> clear();

  Future<Activity?> getLastActivity();
  Future<void> addActivity(Activity activity);
  Stream<Activity> getActivityStream(int page, int limit);

  static Future<void> ensureInitialized() async {
    logger.i('Initialising Database!');
    final db = DatabaseImpl();
    await db.init();
    register<Database>(db);
    logger.i('Initialised Database!');
    await locateAsync<PreferenceService>();
    if (settings.sync.enabled.value && settings.sync.path.value != null) {
      logger.i('Syncing database with local file...');
      locate<Database>().merge(settings.sync.path.value!.absolute.path).then(
            (_) => logger.i('Synced database with local file!'),
            onError: (e) =>
                logger.e('Failed to sync database with local file!', error: e),
          );
    }
  }
}

class DatabaseImpl extends ChangeNotifier implements Database {
  late final AdapterSurrealDB db;

  Future<void> initDB(AdapterSurrealDB db) async {
    await db.use(db: 'default', namespace: 'app');
    await db.setMigrationAdapter(
      version: 1,
      migrationName: 'app',
      onMigrate: (db, from, to) async {},
      onCreate: (db) async {
        //TODO: Fix this
        // await db.query(
        //   query: await rootBundle.loadString('assets/db/schema/schema.surql'),
        // );
      },
    );
    await db.setCrdtAdapter(tablesToSync: {const DBTable('entry')});
  }

  @override
  Future<void> init() async {
    await RustLib.init();
    final dir = await locateAsync<DirectoryProvider>();
    db = await AdapterSurrealDB.newFile(dir.databasepath.absolute.path);
    await initDB(db);
  }

  @override
  Stream<EntrySaved> getEntries(int page, int limit) {
    return getEntriesSQL(
      'SELECT * FROM entry LIMIT \$limit START \$offset*\$limit',
      {
        'limit': limit,
        'offset': page,
      },
    );
  }

  @override
  Stream<EntrySaved> getEntriesSQL(
    String sqlfilter,
    Map<String, dynamic>? vars,
  ) async* {
    final [dbres as List<dynamic>?] = await db.query(
      query: sqlfilter,
      vars: vars,
    );
    if (dbres == null || dbres.isEmpty) return;
    for (final e in dbres) {
      try {
        yield EntrySaved.fromJson(e as Map<String, dynamic>);
      } catch (e) {
        logger.e('Error loading entry', error: e);
      }
    }
  }

  @override
  Future<Activity?> getLastActivity() async {
    final [dbres as List<dynamic>?] = await db.query(
      query: 'SELECT * FROM activity ORDER BY time DESC LIMIT 1',
    );
    if (dbres == null || dbres.isEmpty) return null;
    final activity = Activity.fromDBJson(dbres[0] as Map<String, dynamic>);
    return activity;
  }

  @override
  Future<void> addActivity(Activity activity) async {
    print("Adding activity ${activity.id}");
    await db.upsert(
      res: DBRecord('activity', activity.id),
      data: activity.toDBJson(),
    );
    notifyListeners();
  }

  @override
  Stream<Activity> getActivityStream(int page, int limit) async* {
    final [dbres as List<dynamic>?] = await db.query(
      query:
          'SELECT * FROM activity ORDER BY time DESC LIMIT \$limit START \$offset*\$limit',
      vars: {
        'limit': limit,
        'offset': page,
      },
    );
    if (dbres == null || dbres.isEmpty) return;
    for (final e in dbres) {
      if (e is! Map<String, dynamic>) {
        continue;
      }
      try {
        yield Activity.fromDBJson(e);
      } catch (err) {
        logger.e('Error loading activity $e', error: err);
      }
    }
  }

  DBRecord _constructDBEntryRecord(String entryid, String extensionid) =>
      DBRecord(
        'entry',
        base64.encode(utf8.encode('${entryid}_$extensionid')),
      );

  @override
  Future<EntrySaved?> isSaved(Entry entry) async {
    final dbentry = await db.select(
      res: _constructDBEntryRecord(entry.id, entry.extension.id),
    );
    if (dbentry == null) return null;
    return EntrySaved.fromJson(dbentry as Map<String, dynamic>);
  }

  @override
  Future<EntrySaved?> getEntry(String id, Extension extension) async {
    final dbentry =
        await db.select(res: _constructDBEntryRecord(id, extension.data.id));
    if (dbentry == null) return null;
    return EntrySaved.fromJson(dbentry as Map<String, dynamic>);
  }

  @override
  Future<void> removeEntry(EntryDetailed entry) async {
    await db.delete(res: _constructDBEntryRecord(entry.id, entry.extension.id));
    notifyListeners();
  }

  @override
  Future<void> updateEntry(EntryDetailed entry) async {
    await db.upsert(
      res: _constructDBEntryRecord(entry.id, entry.extension.id),
      data: entry,
    );
    notifyListeners();
  }

  @override
  Future<void> clear() async {
    await db.query(query: 'DELETE entry');
    await db.query(query: 'DELETE activity');
  }

  @override
  Future<void> merge(String path) async {
    final otherdb = await AdapterSurrealDB.newFile(path);
    try {
      await initDB(otherdb);
      await db.getAdapter<CrdtAdapter>().mergeCrdt(otherdb.getAdapter());
    } finally {
      otherdb.dispose();
    }
  }

  @override
  Future<ExtensionMetaData> getExtensionMetaData(ExtensionData extdata) async {
    final data = await db.select(res: DBRecord('extension', extdata.id));
    if (data != null) {
      return ExtensionMetaData(extdata.id, data['enabled'] as bool);
    }
    return ExtensionMetaData(extdata.id, true);
  }

  @override
  Future<void> setExtensionMetaData(
      Extension extension, ExtensionMetaData data) async {
    await db.upsert(
      res: DBRecord('extension', data.id),
      data: {
        'enabled': data.enabled,
      },
    );
  }
}
