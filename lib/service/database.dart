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
import 'package:uuid/uuid.dart';

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

class Category {
  final DBRecord? id;
  final String name;

  Category(this.name, this.id);

  Category copyWith({String? name, DBRecord? id}) {
    return Category(name ?? this.name, id ?? this.id);
  }

  Category.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        id = json['id'] as DBRecord?;

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
      };

  @override
  bool operator ==(Object other) {
    return other is Category && other.name == name && other.id == id;
  }

  @override
  int get hashCode => Object.hash(name, id);
}

class Database extends ChangeNotifier {
  late final AdapterSurrealDB db;

  static Future<void> ensureInitialized() async {
    logger.i('Initialising Database!');
    final db = Database();
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

  Future<void> init() async {
    await RustLib.init();
    final dir = await locateAsync<DirectoryProvider>();
    db = await AdapterSurrealDB.newFile(dir.databasepath.absolute.path);
    await initDB(db);
  }

  Future<List<Category>> getCategories() async {
    final [dbres as List<dynamic>?] = await db.query(
      query: 'SELECT * FROM category',
    );
    if (dbres == null || dbres.isEmpty) return [];
    return dbres
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateCategory(Category category) async {
    final id = category.id ?? DBRecord('category', const Uuid().v4());
    await db.upsert(
      res: id,
      data: category.copyWith(id: id).toJson(),
    );
    notifyListeners();
  }

  Future<void> removeCategory(Category category) async {
    await db.delete(res: category.id!);
    notifyListeners();
  }

  Future<List<Category>> getCategory(List<DBRecord> ids) async {
    if (ids.isEmpty) return [];
    final [dbres as List<dynamic>?] = await db.query(
      query: 'SELECT * FROM category WHERE id IN \$ids',
      vars: {
        'ids': ids,
      },
    );
    if (dbres == null || dbres.isEmpty) return [];
    return dbres
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<EntrySaved> getEntriesInCategory(
      Category category, int page, int limit,) {
    return getEntriesSQL(
      'SELECT * FROM entry WHERE categories CONTAINS \$category LIMIT \$limit START \$offset*\$limit',
      {
        'limit': limit,
        'offset': page,
        'category': category.id,
      },
    );
  }

  Stream<EntrySaved> getEntries(int page, int limit) {
    return getEntriesSQL(
      'SELECT * FROM entry LIMIT \$limit START \$offset*\$limit',
      {
        'limit': limit,
        'offset': page,
      },
    );
  }

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
        yield await EntrySaved.fromJson(e as Map<String, dynamic>);
      } catch (e) {
        logger.e('Error loading entry', error: e);
      }
    }
  }

  Future<Activity?> getLastActivity() async {
    final [dbres as List<dynamic>?] = await db.query(
      query: 'SELECT * FROM activity ORDER BY time DESC LIMIT 1',
    );
    if (dbres == null || dbres.isEmpty) return null;
    final activity = Activity.fromDBJson(dbres[0] as Map<String, dynamic>);
    return activity;
  }

  Future<void> addActivity(Activity activity) async {
    await db.upsert(
      res: DBRecord('activity', activity.id),
      data: activity.toDBJson(),
    );
    notifyListeners();
  }

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

  Future<Duration> getActivityDuration(DateTime time, Duration duration) async {
    final end = time.add(duration);
    final [dbres] = await db.query(
      query: '''
math::sum(
SELECT VALUE duration FROM activity 
WHERE 
  time >= \$start AND
  time <= \$end AND
  duration > 0
)'''
          .trim(),
      vars: {
        'start': time,
        'end': end,
      },
    );
    return Duration(seconds: dbres as int);
  }

  DBRecord _constructDBEntryRecord(String entryid, String extensionid) =>
      DBRecord(
        'entry',
        base64.encode(utf8.encode('${entryid}_$extensionid')),
      );

  Future<EntrySaved?> isSaved(Entry entry) async {
    final dbentry = await db.select(
      res: _constructDBEntryRecord(entry.id, entry.extension.id),
    );
    if (dbentry == null) return null;
    return EntrySaved.fromJson(dbentry as Map<String, dynamic>);
  }

  Future<EntrySaved?> getEntry(String id, Extension extension) async {
    final dbentry =
        await db.select(res: _constructDBEntryRecord(id, extension.data.id));
    if (dbentry == null) return null;
    return EntrySaved.fromJson(dbentry as Map<String, dynamic>);
  }

  Future<void> removeEntry(EntryDetailed entry) async {
    await db.delete(res: _constructDBEntryRecord(entry.id, entry.extension.id));
    notifyListeners();
  }

  Future<void> updateEntry(EntryDetailed entry) async {
    await db.upsert(
      res: _constructDBEntryRecord(entry.id, entry.extension.id),
      data: entry,
    );
    notifyListeners();
  }

  Future<void> clear() async {
    await db.query(query: 'DELETE entry');
    await db.query(query: 'DELETE activity');
  }

  Future<void> merge(String path) async {
    final otherdb = await AdapterSurrealDB.newFile(path);
    try {
      await initDB(otherdb);
      await db.getAdapter<CrdtAdapter>().mergeCrdt(otherdb.getAdapter());
    } finally {
      otherdb.dispose();
    }
  }

  Future<ExtensionMetaData> getExtensionMetaData(ExtensionData extdata) async {
    final data = await db.select(res: DBRecord('extension', extdata.id));
    if (data != null) {
      return ExtensionMetaData(extdata.id, data['enabled'] as bool);
    }
    return ExtensionMetaData(extdata.id, true);
  }

  Future<void> setExtensionMetaData(
      Extension extension, ExtensionMetaData data,) async {
    await db.upsert(
      res: DBRecord('extension', data.id),
      data: {
        'enabled': data.enabled,
      },
    );
    notifyListeners();
  }
}
