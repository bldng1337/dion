import 'package:async/async.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/entry_duration.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/change.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/adapter/sync/repo.dart';
import 'package:metis/metis.dart';

const dbVersion = 2;
const entryTable = DBTable('entry');
const categoryTable = DBTable('category');
const activityTable = DBTable('activity');
const extensionTable = DBTable('extension');

enum DBEvent {
  entryUpdated,
  entryAddedOrRemoved,
  categoryUpdated,
  activityUpdated,
  extensionMetaDataUpdated,
}

class Database extends KeyedChangeNotifier<DBEvent> {
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
    await db.query('''
DEFINE TABLE IF NOT EXISTS entry;
DEFINE TABLE IF NOT EXISTS category;
DEFINE TABLE IF NOT EXISTS activity;
DEFINE TABLE IF NOT EXISTS extension;
      ''');
    final dataclass = await db.setDataClassAdapter();
    dataclass.registerDataClass(Category.fromJson);
    dataclass.registerDataClass(EntrySaved.fromJson);
    dataclass.registerDataClass(Activity.fromJson);
    dataclass.registerDataClass(ExtensionMetaData.fromJson);
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
    await db.setMigrationAdapter(
      version: dbVersion,
      migrationName: 'app',
      onMigrate: (migrateDb, from, to) async {
        if (from < 2) {
          final adapter = db.getAdapter<DBDataClassAdapter>();
          await _migrateBatched<Activity>(adapter, activityTable);
          await _migrateBatched<EntrySaved>(
            adapter,
            entryTable,
            fetch: 'categories',
          );
        }
      },
      onCreate: (db) {},
    );
    this.db = db;
  }

  Future<void> _migrateBatched<T extends DBConstClass>(
    DBDataClassAdapter adapter,
    DBTable table, {
    String? fetch,
  }) async {
    const batchSize = 200;
    final fetchClause = fetch == null ? '' : ' FETCH $fetch';
    var offset = 0;
    while (true) {
      final batch = await adapter
          .queryDataClasses<T>(
            query:
                'SELECT * FROM type::table(\$table) ORDER BY id LIMIT \$limit START \$offset$fetchClause',
            vars: {'table': table.tb, 'limit': batchSize, 'offset': offset},
          )
          .toList();
      if (batch.isEmpty) break;
      for (final item in batch) {
        try {
          await adapter.save(item);
        } catch (e, stack) {
          logger.e(
            'Failed to migrate ${table.tb} record',
            error: e,
            stackTrace: stack,
          );
        }
      }
      if (batch.length < batchSize) break;
      offset += batchSize;
    }
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
    notifyListeners([DBEvent.categoryUpdated]);
  }

  Future<void> updateCategories(List<Category> categories) async {
    for (final category in categories) {
      await adapter.save(category);
    }
    notifyListeners([DBEvent.categoryUpdated]);
  }

  Future<void> removeCategory(Category category) async {
    await adapter.delete(category);
    notifyListeners([DBEvent.categoryUpdated]);
  }

  Future<List<Category>> getCategoriesbyId(Iterable<DBRecord> ids) async {
    if (ids.isEmpty) return [];
    final res = await Future.wait(
      ids.map((e) => adapter.selectDataClass<Category>(e)),
    );
    return res.nonNulls.toList();
  }

  Future<List<Category>> getCategoriesByName(Iterable<String> names) async {
    if (names.isEmpty) return [];
    final res = await adapter
        .queryDataClasses<Category>(
          query: 'SELECT * FROM type::table(\$category) WHERE name IN \$names',
          vars: {'category': categoryTable.tb, 'names': names.toList()},
        )
        .toList();
    return res;
  }

  Future<int> getNumEntries() async {
    return await _countSQL(
      query: 'SELECT count() FROM type::table(\$entry) GROUP ALL;',
      vars: {'entry': entryTable.tb},
    );
  }

  Future<int> getNumEntriesInCategory(Category? category) async {
    if (category == null) {
      return await _countSQL(
        query:
            'SELECT count() FROM type::table(\$entry) WHERE array::is_empty(categories??[]) GROUP ALL;',
        vars: {'entry': entryTable.tb},
      );
    }
    return await _countSQL(
      query:
          'SELECT count() FROM type::table(\$entry) WHERE categories CONTAINS \$category GROUP ALL;',
      vars: {'category': category.id, 'entry': entryTable.tb},
    );
  }

  Stream<EntrySaved> getEntries(int page, int limit) {
    return _getEntriesSQL(
      'SELECT * FROM type::table(\$entry) LIMIT \$limit START \$offset*\$limit FETCH categories',
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
        'SELECT * FROM type::table(\$entry) WHERE count(categories) = 0 LIMIT \$limit START \$offset*\$limit FETCH categories',
        {'limit': limit, 'offset': page, 'entry': entryTable.tb},
      );
    }
    return _getEntriesSQL(
      'SELECT * FROM type::table(\$entry) WHERE categories CONTAINS \$category LIMIT \$limit START \$offset*\$limit FETCH categories',
      {
        'limit': limit,
        'offset': page,
        'category': category.id,
        'entry': entryTable.tb,
      },
    );
  }

  Stream<EntrySaved> searchEntries(String query, int page, int limit) {
    return _getEntriesSQL(
      'SELECT * FROM type::table(\$entry) WHERE '
      'array::any(entry.titles, |\$t| string::contains(string::lowercase(\$t), \$query)) OR '
      '(entry.author != NONE AND array::any(entry.author, |\$a| string::contains(string::lowercase(\$a), \$query))) '
      'LIMIT \$limit START \$offset*\$limit FETCH categories',
      {
        'entry': entryTable.tb,
        'query': query.toLowerCase(),
        'limit': limit,
        'offset': page,
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
    notifyListeners([DBEvent.activityUpdated]);
  }

  Future<void> addActivities(Iterable<Activity> activities) async {
    for (final activity in activities) {
      await adapter.save(activity);
    }
    notifyListeners([DBEvent.activityUpdated]);
  }

  Future<void> clearActivities() async {
    await db.query('DELETE activity');
    notifyListeners([DBEvent.activityUpdated]);
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

  Future<Map<DateTime, Duration>> getDailyActivityDurations({
    DateTime? startDate,
    int days = 365,
  }) async {
    final start =
        startDate ?? DateTime.now().subtract(Duration(days: days)).toUtc();
    final end = DateTime.now().toUtc();

    final [res] = await db.query(
      '''
SELECT time::format(time, '%Y-%m-%d') AS dayStr, math::sum(duration) AS totalDuration
FROM activity
WHERE
  time >= \$start AND
  time <= \$end AND
  duration > 0
GROUP BY dayStr
ORDER BY dayStr ASC
'''
          .trim(),
      vars: {'start': start, 'end': end},
    );

    final Map<DateTime, Duration> result = {};

    // Handle the result array
    if (res is! List) {
      logger.e('Expected result to be a list, got: ${res.runtimeType}');
      return result;
    }

    for (final row in res) {
      if (row is! Map) {
        logger.e('Expected row to be a map, got: ${row.runtimeType}');
        continue;
      }

      final dayStr = row['dayStr'] as String?;
      final totalDuration = row['totalDuration'];

      if (dayStr == null) {
        logger.w('Skipping row with null dayStr');
        continue;
      }
      final parts = dayStr.split('-');
      final day = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      if (totalDuration is Duration) {
        result[day] = totalDuration;
        continue;
      }
      if (totalDuration is num) {
        result[day] = Duration(seconds: totalDuration.toInt());
        continue;
      }
      result[day] = Duration.zero;
    }

    return result;
  }

  Future<List<EntryDuration>> getEntryDurations({int days = 365}) async {
    final start = DateTime.now().subtract(Duration(days: days)).toUtc();

    final [aggRes] = await db.query(
      '''
SELECT
  entry.entry.id.uid AS uid,
  math::sum(duration) AS total
FROM activity
WHERE
  time >= \$start AND
  duration > 0
GROUP BY uid
ORDER BY total DESC
'''
          .trim(),
      vars: {'start': start},
    );

    if (aggRes is! List || aggRes.isEmpty) return [];

    final order = <String>[];
    final totals = <String, Duration>{};
    for (final row in aggRes) {
      if (row is! Map) continue;
      final uid = row['uid'];
      final total = row['total'];
      if (uid is! String || total == null) continue;
      order.add(uid);
      totals[uid] = Duration(seconds: (total as num).toInt());
    }
    if (order.isEmpty) return [];

    final byUid = <String, Entry>{};
    final saved = await adapter
        .queryDataClasses<EntrySaved>(
          query:
              'SELECT * FROM type::table(\$entry) WHERE entry.id.uid IN \$uids FETCH categories',
          vars: {'entry': entryTable.tb, 'uids': order},
        )
        .toList();
    for (final e in saved) {
      byUid[e.id.uid] = e;
    }

    final missing = order.where((u) => !byUid.containsKey(u)).toList();
    if (missing.isNotEmpty) {
      final [actRes] = await db.query(
        'SELECT entry, time FROM activity WHERE entry.entry.id.uid IN \$uids ORDER BY time DESC',
        vars: {'uids': missing},
      );
      if (actRes is List) {
        for (final row in actRes) {
          if (row is! Map) continue;
          final entryJson = row['entry'];
          if (entryJson == null) continue;
          try {
            final entry = Entry.fromJson(
              Map<String, dynamic>.from(entryJson as Map),
            );
            byUid.putIfAbsent(entry.id.uid, () => entry);
          } catch (e, stack) {
            logger.e(
              'Failed to parse activity entry payload',
              error: e,
              stackTrace: stack,
            );
          }
        }
      }
    }

    return [
      for (final uid in order)
        if (byUid.containsKey(uid) && totals[uid] != null)
          EntryDuration(entry: byUid[uid]!, duration: totals[uid]!),
    ];
  }

  Future<EntrySaved?> getSavedById(EntryId entry) async {
    return await adapter
        .queryDataClasses<EntrySaved>(
          query: 'SELECT * FROM type::table(\$entry) WHERE entry.id.uid = \$id',
          vars: {'entry': entryTable.tb, 'id': entry.uid},
        )
        .firstOrNull;
  }

  Future<EntrySaved?> isSaved(Entry entry) async {
    return await adapter.selectDataClass(entry.dbId);
  }

  Future<void> removeEntry(EntrySaved entry) async {
    await adapter.delete(entry);
    notifyListeners([DBEvent.entryAddedOrRemoved]);
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

  Future<void> addEntry(EntrySaved entry) async {
    await adapter.save(entry);
    notifyListeners([DBEvent.entryAddedOrRemoved]);
  }

  Future<void> updateEntry(EntrySaved entry) async {
    await adapter.save(entry);
    notifyListeners([DBEvent.entryUpdated]);
  }

  Future<void> clear() async {
    await db.query('DELETE entry');
    await db.query('DELETE activity');
    await db.query('DELETE category');
    await db.query('DELETE extension');
  }

  Future<void> merge(String path) async {
    final otherdbConnection = await AdapterSurrealDB.connect(
      'surrealkv://$path',
    );
    final otherdb = Database();
    try {
      await otherdb.initDB(otherdbConnection);
      final localAdapter = db.getAdapter<CrdtAdapter>();
      final remoteAdapter = otherdb.db.getAdapter<CrdtAdapter>();
      await localAdapter.sync(remoteAdapter.syncRepo);
    } finally {
      otherdbConnection.dispose();
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
    notifyListeners([DBEvent.extensionMetaDataUpdated]);
  }
}
