import 'package:async/async.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/appsettings.dart';
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
const entryTable = DBTable('entry');
const categoryTable = DBTable('category');
const activityTable = DBTable('activity');
const extensionTable = DBTable('extension');

class Database extends ChangeNotifier {
  late final AdapterSurrealDB db;

  DBDataClassAdapter get adapter => db.getAdapter();

  static Future<void> ensureInitialized() async {
    final db = Database();
    await db.init();
    register<Database>(db);
    logger.i('Initialised Database!');
    await locateAsync<PreferenceService>(); //Rework this into a more sane way
    if (settings.sync.enabled.value && settings.sync.path.value != null) {
      logger.i('Syncing database with local file...');
      try {
        await locate<Database>().merge(settings.sync.path.value!.absolute.path);
        logger.i('Synced database with local file!');
      } catch (e) {
        logger.e('Failed to sync database with local file!', error: e);
      }
    }
  }

  Future<void> initDB(AdapterSurrealDB db) async {
    await db.use(db: 'default', ns: 'app');
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
          table: entryTable,
        ),
        SyncTable(
          version: dbVersion,
          range: VersionRange.exact(dbVersion),
          table: categoryTable,
        ),
        SyncTable(
          version: dbVersion,
          range: VersionRange.exact(dbVersion),
          table: extensionTable,
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
    await SurrealDB.ensureInitialized();
    late final AdapterSurrealDB currentdb;
    if (inMemory) {
      currentdb = await AdapterSurrealDB.connect('memory://');
    } else {
      final dir = await locateAsync<DirectoryProvider>();
      currentdb = await AdapterSurrealDB.connect(
        'surrealkv://${dir.databasepath.absolute.path}',
      );
    }
    await initDB(currentdb);
  }

  // Category

  Future<List<Category>> getCategories() async {
    return await adapter
        .queryDataClasses<Category>(
          query: 'SELECT * FROM type::table(\$category) ORDER BY index ASC',
          vars: {'category': categoryTable.tb},
        )
        .toList();
    // return await adapter.selectDataClasses<Category>(categoryTable).toList();
  }

  Future<void> updateCategory(Category category) async {
    await adapter.save(category);
    notifyListeners();
  }

  Future<void> updateCategories(List<Category> categories) async {
    for (final category in categories) {
      await adapter.save(category);
    }
    notifyListeners();
  }

  Future<void> removeCategory(Category category) async {
    await adapter.delete(category);
    notifyListeners();
  }

  Future<List<Category>> getCategoriesbyId(Iterable<DBRecord> ids) async {
    if (ids.isEmpty) return [];
    final res = await Future.wait(
      ids.map((e) => adapter.selectDataClass<Category>(e)),
    );
    return res.nonNulls.toList();
  }

  Future<int> getNumEntries() async {
    return await _countSQL(
      query: 'SELECT count() FROM type::table(\$entry)',
      vars: {'entry': entryTable.tb},
    );
  }

  Future<int> getNumEntriesInCategory(Category? category) async {
    if (category == null) {
      return await _countSQL(
        query:
            'SELECT count() FROM type::table(\$entry) WHERE count(categories) = 0',
        vars: {'entry': entryTable.tb},
      );
    }
    return await _countSQL(
      query:
          'SELECT count() FROM type::table(\$entry) WHERE categories CONTAINS \$category',
      vars: {'category': category.id, 'entry': entryTable.tb},
    );
  }

  Stream<EntrySaved> getEntries(int page, int limit) {
    return _getEntriesSQL(
      'SELECT * FROM type::table(\$entry) LIMIT \$limit START \$offset*\$limit',
      {'limit': limit, 'offset': page, 'entry': entryTable.tb},
    );
  }

  Stream<EntrySaved> getEntriesInCategory(
    Category? category,
    int page,
    int limit,
  ) {
    if (category == null) {
      return _getEntriesSQL(
        'SELECT * FROM type::table(\$entry) WHERE count(categories) = 0 LIMIT \$limit START \$offset*\$limit',
        {'limit': limit, 'offset': page, 'entry': entryTable.tb},
      );
    }
    return _getEntriesSQL(
      'SELECT * FROM type::table(\$entry) WHERE categories CONTAINS \$category LIMIT \$limit START \$offset*\$limit',
      {
        'limit': limit,
        'offset': page,
        'category': category.id,
        'entry': entryTable.tb,
      },
    );
  }

  Future<int> _countSQL({
    required String query,
    Map<String, dynamic>? vars,
  }) async {
    final [res as List<dynamic>] = await db.query(query, vars: vars);
    if (res.isEmpty) return 0;
    return res[0]['count'] as int;
  }

  Stream<EntrySaved> _getEntriesSQL(
    String sqlfilter,
    Map<String, dynamic>? vars,
  ) {
    return adapter.queryDataClasses<EntrySaved>(query: sqlfilter, vars: vars);
  }

  Future<Activity?> getLastActivity() async {
    return await adapter
        .queryDataClasses<Activity>(
          query:
              'SELECT * FROM type::table(\$activity) ORDER BY time DESC LIMIT 1',
          vars: {'activity': activityTable.tb},
        )
        .firstOrNull;
  }

  Future<void> addActivity(Activity activity) async {
    await adapter.save(activity);
    notifyListeners();
  }

  Stream<Activity> getActivities(int page, int limit) {
    return adapter.queryDataClasses<Activity>(
      query:
          'SELECT * FROM activity ORDER BY time DESC LIMIT \$limit START \$offset*\$limit',
      vars: {'limit': limit, 'offset': page},
    );
  }

  Future<Duration> getActivityDuration(DateTime time, Duration duration) async {
    final end = time.add(duration);
    final [dbres] = await db.query(
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
      // TODO: Consider whether to rethrow or continue
    }
  }

  Future<void> updateEntry(EntrySaved entry) async {
    await adapter.save(entry);
    notifyListeners();
  }

  Future<void> clear() async {
    await db.query('DELETE entry');
    await db.query('DELETE activity');
    await db.query('DELETE category');
    await db.query('DELETE extension');
  }

  Future<void> merge(String path) async {
    final otherdb = await AdapterSurrealDB.connect('surrealkv://$path');
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
