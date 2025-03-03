import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_surrealdb/flutter_surrealdb.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

abstract class Database extends ChangeNotifier {
  Future<void> init();

  Future<void> merge(String path); //TODO: merge

  Stream<EntrySaved> getEntries(int page, int limit);
  Stream<EntrySaved> getEntriesSQL(
    String sqlfilter,
    Map<String, dynamic>? vars,
  );
  Future<EntrySaved?> isSaved(Entry entry);
  Future<void> removeEntry(EntryDetailed entry);
  Future<void> updateEntry(EntryDetailed entry);
  Future<void> clear();

  static Future<void> ensureInitialized() async {
    logger.i('Initialising Database!');
    final db = DatabaseImpl();
    await db.init();
    register<Database>(db);
    logger.i('Initialised Database!');
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
        yield constructEntry(
          e as Map<String, dynamic>,
          locate<SourceExtension>().getExtension(e['extensionid']! as String),
        );
      } catch (e) {
        logger.e('Error loading entry', error: e);
      }
    }
  }

  DBRecord _constructDBRecord(Entry entry) =>
      DBRecord('entry', '${entry.id}_${entry.extension.id}');

  @override
  Future<EntrySaved?> isSaved(Entry entry) async {
    final dbentry = await db.select(res: _constructDBRecord(entry));
    if (dbentry == null) return null;
    return constructEntry(dbentry as Map<String, dynamic>, entry.extension);
  }

  EntrySaved constructEntry(
    Map<String, dynamic> dbentry,
    Extension extension,
  ) {
    final episodedata = <EpisodeData>[];
    if (dbentry['episodedata'] != null) {
      for (final epdata in dbentry['episodedata'] as List<dynamic>) {
        episodedata.add(
          EpisodeData(
            bookmark: epdata['bookmark'] as bool,
            finished: epdata['finished'] as bool,
            progress: epdata['progress'] as String?,
          ),
        );
      }
    }
    final episodelists = <EpisodeList>[];
    if (dbentry['episodes'] != null) {
      for (final eplist in dbentry['episodes'] as List<dynamic>) {
        final episodes = <Episode>[];
        for (final ep in eplist['episodes'] as List<dynamic>) {
          episodes.add(
            Episode(
              id: ep['episodeid']! as String,
              name: ep['name']! as String,
              url: ep['url']! as String,
              cover: ep['cover'] as String?,
              coverHeader: (ep['coverheader'] as Map<String, dynamic>?)?.cast(),
              timestamp: ep['timestamp'] as String?,
            ),
          );
        }
        episodelists.add(
          EpisodeList(
            title: eplist['title']! as String,
            episodes: episodes,
          ),
        );
      }
    }
    return EntrySavedImpl(
      rust.EntryDetailed(
        id: dbentry['entryid']! as String,
        url: dbentry['url']! as String,
        title: dbentry['title']! as String,
        status: rust.ReleaseStatus.values
            .firstWhere((e) => e.name == dbentry['status']! as String),
        description: dbentry['description']! as String,
        language: dbentry['language']! as String,
        episodes: episodelists,
        genres: (dbentry['genres'] as List<dynamic>?)?.cast(),
        alttitles: (dbentry['alttitles'] as List<dynamic>?)?.cast(),
        author: (dbentry['author'] as List<dynamic>?)?.cast(),
        cover: dbentry['cover'] as String?,
        coverHeader: (dbentry['coverheader'] as Map<String, dynamic>?)?.cast(),
        mediaType: rust.MediaType.values
            .firstWhere((e) => e.name == (dbentry['mediatype']! as String)),
        rating: dbentry['rating'] as double?,
        views: (dbentry['views'] as int?)?.toDouble(),
        length: dbentry['length'] as int?,
        ui: _constructCustomUI(dbentry['ui'] as Map<String, dynamic>?),
      ),
      extension,
      episodedata,
    );
  }

  @override
  Future<void> removeEntry(EntryDetailed entry) async {
    await db.delete(res: _constructDBRecord(entry));
    notifyListeners();
  }

  @override
  Future<void> updateEntry(EntryDetailed entry) async {
    final dbentry = <String, dynamic>{
      'entryid': entry.id,
      'url': entry.url,
      'title': entry.title,
      'status': entry.status.name,
      'description': entry.description,
      'language': entry.language,
      'genres': entry.genres,
      'alttitles': entry.alttitles,
      'author': entry.author,
      'cover': entry.cover,
      'coverheader': entry.coverHeader,
      'mediatype': entry.mediaType.name,
      'rating': entry.rating,
      'views': entry.views?.toInt(),
      'length': entry.length,
      'ui': _destructCustomUI(entry.ui),
      'extensionid': entry.extension.id,
    };
    final episodelists = [];
    for (final episodelist in entry.episodes) {
      episodelists.add({
        'title': episodelist.title,
        'episodes': episodelist.episodes
            .map(
              (e) => {
                'episodeid': e.id,
                'name': e.name,
                'url': e.url,
                'cover': e.cover,
                'coverheader': e.coverHeader,
                'timestamp': e.timestamp,
              },
            )
            .toList(),
      });
    }
    dbentry['episodes'] = episodelists;
    if (entry is EntrySaved) {
      final episodedata = [];
      for (final epdata in entry.episodedata) {
        episodedata.add({
          'bookmark': epdata.bookmark,
          'finished': epdata.finished,
          'progress': epdata.progress,
        });
      }
      dbentry['episodedata'] = episodedata;
    }
    await db.upsert(res: _constructDBRecord(entry), data: dbentry);
    notifyListeners();
  }

  CustomUI? _constructCustomUI(dynamic ui) {
    if (ui == null) return null;
    return switch (ui['type']) {
      'text' => CustomUI_Text(text: ui['text'] as String),
      'image' => CustomUI_Image(
          image: ui['image'] as String,
          header: (ui['header'] as Map<String, dynamic>?)?.cast(),
        ),
      'link' => CustomUI_Link(
          link: ui['link'] as String,
          label: ui['label'] as String?,
        ),
      'timestamp' => CustomUI_TimeStamp(
          timestamp: ui['timestamp'] as String,
          display: rust.TimestampType.values
              .firstWhere((e) => e.name == ui['display'] as String),
        ),
      'entrycard' => CustomUI_EntryCard(
          entry: rust.Entry(
            id: ui['entry']['entryid'] as String,
            url: ui['entry']['url'] as String,
            title: ui['entry']['title'] as String,
            author: (ui['entry']['author'] as List<dynamic>?)?.cast(),
            cover: ui['entry']['cover'] as String?,
            mediaType: rust.MediaType.values.firstWhere(
              (e) => e.name == ui['entry']['mediatype'] as String,
            ),
            coverHeader:
                (ui['entry']['coverheader'] as Map<String, dynamic>?)?.cast(),
            rating: ui['entry']['rating'] as double?,
            views: ui['entry']['views'] as double?,
            length: ui['entry']['length'] as int?,
          ),
        ),
      'column' => CustomUI_Column(
          children: (ui['children'] as List<dynamic>)
              .map(_constructCustomUI)
              .where((e) => e != null)
              .toList()
              .cast(),
        ),
      'row' => CustomUI_Row(
          children: (ui['children'] as List<dynamic>)
              .map(_constructCustomUI)
              .where((e) => e != null)
              .toList()
              .cast(),
        ),
      _ => null,
    };
  }

  dynamic _destructCustomUI(CustomUI? ui) {
    return switch (ui) {
      final CustomUI_Text text => {
          'type': 'text',
          'text': text.text,
        },
      final CustomUI_Image img => {
          'type': 'image',
          'image': img.image,
          'header': img.header,
        },
      final CustomUI_Link link => {
          'type': 'link',
          'link': link.link,
          'label': link.label,
        },
      final CustomUI_TimeStamp timestamp => {
          'type': 'timestamp',
          'timestamp': timestamp.timestamp,
          'display': timestamp.display.name,
        },
      final CustomUI_EntryCard entryCard => {
          'type': 'entrycard',
          'entry': {
            'entryid': entryCard.entry.id,
            'url': entryCard.entry.url,
            'title': entryCard.entry.title,
            'author': entryCard.entry.author,
            'cover': entryCard.entry.cover,
            'coverheader': entryCard.entry.coverHeader,
            'rating': entryCard.entry.rating,
            'views': entryCard.entry.views,
            'length': entryCard.entry.length,
            'mediatype': entryCard.entry.mediaType.name,
          },
        },
      final CustomUI_Column column => {
          'type': 'column',
          'children': column.children.map(_destructCustomUI).toList(),
        },
      final CustomUI_Row row => {
          'type': 'row',
          'children': row.children.map(_destructCustomUI).toList(),
        },
      null => null,
    };
  }

  @override
  Future<void> clear() async {
    await db.query(query: 'DELETE entry');
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
}
