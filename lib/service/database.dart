import 'package:async/async.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/adapter/sync/repo.dart';
import 'package:metis/metis.dart';

const dbVersion = 1;

class Database extends ChangeNotifier {
  late final AdapterSurrealDB db;

  DBDataClassAdapter get adapter => db.getAdapter();

  static Future<void> ensureInitialized() async {
    final db = Database();
    await db.init();
    register<Database>(db);
    logger.i('Initialised Database!');
    await locateAsync<PreferenceService>();
    if (settings.sync.enabled.value && settings.sync.path.value != null) {
      logger.i('Syncing database with local file...');
      locate<Database>()
          .merge(settings.sync.path.value!.absolute.path)
          .then(
            (_) => logger.i('Synced database with local file!'),
            onError: (e) =>
                logger.e('Failed to sync database with local file!', error: e),
          );
    }
  }

  Future<void> initDB(AdapterSurrealDB db) async {
    await db.use(db: 'default', namespace: 'app');
    await db.setMigrationAdapter(
      version: dbVersion,
      migrationName: 'app',
      onMigrate: (db, from, to) async {},
      onCreate: (db) async {},
    );
    await db.setCrdtAdapter(
      tablesToSync: const {
        SyncTable(
          version: dbVersion,
          range: VersionRange.exact(dbVersion),
          table: DBTable('entry'),
        ),
        SyncTable(
          version: dbVersion,
          range: VersionRange.exact(dbVersion),
          table: DBTable('category'),
        ),
      },
    );
    final dataclass = await db.setDataClassAdapter();
    dataclass.registerDataClass(Category.fromJson);
    dataclass.registerDataClass(EntrySaved.fromJson);
    dataclass.registerDataClass(Activity.fromJson);
    dataclass.registerDataClass(ExtensionMetaData.fromJson);
    this.db = db;
  }

  Future<void> init({bool inMemory = false}) async {
    await RustLib.init();
    final dir = await locateAsync<DirectoryProvider>();
    late final AdapterSurrealDB currentdb;
    if (inMemory) {
      currentdb = await AdapterSurrealDB.newMem();
    } else {
      currentdb = await AdapterSurrealDB.newFile(
        dir.databasepath.absolute.path,
      );
    }
    await initDB(currentdb);
  }

  Future<List<Category>> getCategories() async {
    return await adapter
        .queryDataClasses<Category>(query: 'SELECT * FROM category')
        .toList();
  }

  Future<void> updateCategory(Category category) async {
    await adapter.save(category);
    notifyListeners();
  }

  Future<void> removeCategory(Category category) async {
    await adapter.delete(category);
    notifyListeners();
  }

  Future<List<Category>> getCategory(List<DBRecord> ids) async {
    if (ids.isEmpty) return [];
    return adapter.selectDataClasses<Category>(ids).toList();
  }

  Stream<EntrySaved> getEntriesInCategory(
    Category category,
    int page,
    int limit,
  ) {
    return getEntriesSQL(
      'SELECT * FROM entry WHERE categories CONTAINS \$category LIMIT \$limit START \$offset*\$limit',
      {'limit': limit, 'offset': page, 'category': category.id},
    );
  }

  Stream<EntrySaved> getEntries(int page, int limit) {
    return getEntriesSQL(
      'SELECT * FROM entry LIMIT \$limit START \$offset*\$limit',
      {'limit': limit, 'offset': page},
    );
  }

  Stream<EntrySaved> getEntriesSQL(
    String sqlfilter,
    Map<String, dynamic>? vars,
  ) {
    return adapter.queryDataClasses<EntrySaved>(query: sqlfilter, vars: vars);
  }

  Future<Activity?> getLastActivity() async {
    return adapter
        .queryDataClasses<Activity>(
          query: 'SELECT * FROM activity ORDER BY time DESC LIMIT 1',
        )
        .firstOrNull;
  }

  Future<void> addActivity(Activity activity) async {
    await adapter.save(activity);
    notifyListeners();
  }

  Stream<Activity> getActivityStream(int page, int limit) {
    return adapter.queryDataClasses<Activity>(
      query:
          'SELECT * FROM activity ORDER BY time DESC LIMIT \$limit START \$offset*\$limit',
      vars: {'limit': limit, 'offset': page},
    );
  }

  Future<Duration> getActivityDuration(DateTime time, Duration duration) async {
    final end = time.add(duration);
    final [dbres] = await db.query(
      query:
          '''
math::sum(
SELECT VALUE duration FROM activity 
WHERE 
  time >= \$start AND
  time <= \$end AND
  duration > 0
)'''
              .trim(),
      vars: {'start': time, 'end': end},
    );
    return Duration(seconds: dbres as int);
  }

  Future<EntrySaved?> isSaved(Entry entry) async {
    return adapter.selectDataClass(constructEntryDBRecord(entry));
  }

  Future<void> removeEntry(EntrySaved entry) async {
    await adapter.delete(entry);
    notifyListeners();
    final download = locate<DownloadService>();
    try {
      await download.deleteEntry(entry);
    } catch (e, stack) {
      logger.e(
        'Failed to cleanup downloads for entry',
        error: e,
        stackTrace: stack,
      );
      // Consider whether to rethrow or continue
    }
  }

  Future<void> updateEntry(EntrySaved entry) async {
    await adapter.save(entry);
    notifyListeners();
  }

  Future<void> clear() async {
    await db.query(query: 'DELETE entry');
    await db.query(query: 'DELETE activity');
    await db.query(query: 'DELETE category');
    await db.query(query: 'DELETE extension');
  }

  Future<void> merge(String path) async {
    final otherdb = await AdapterSurrealDB.newFile(path);
    try {
      await initDB(otherdb);
      final CrdtAdapter adapter = db.getAdapter<CrdtAdapter>();
      await db.getAdapter<CrdtAdapter>().sync(adapter.syncRepo);
    } finally {
      otherdb.dispose();
    }
  }

  Future<ExtensionMetaData> getExtensionMetaData(ExtensionData extdata) async {
    final data = await adapter.selectDataClass<ExtensionMetaData>(
      constructExtensionDBRecord(extdata.id),
    );
    return data ?? ExtensionMetaData.empty(extdata.id);
  }

  Future<void> setExtensionMetaData(ExtensionMetaData data) async {
    await adapter.save(data);
    notifyListeners();
  }
}
