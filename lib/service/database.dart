import 'dart:convert';

import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:sqlite_crdt/sqlite_crdt.dart';

abstract class Database extends ChangeNotifier {
  Future<void> init();

  Future<void> merge(String path); //TODO: merge

  Stream<EntrySaved> getEntries(int page, int limit);
  Stream<EntrySaved> getEntriesSQL(int page, int limit, String sqlfilter);
  Future<EntrySaved?> isSaved(Entry entry);
  Future<void> removeEntry(EntryDetailed entry);
  Future<void> updateEntry(EntryDetailed entry);
  Future<void> clear();

  static Future<void> ensureInitialized() async {
    final db = DatabaseImpl();
    await db.init();
    register<Database>(db);
    logger.i('Initialised Database!');
  }
}

class DatabaseImpl extends ChangeNotifier implements Database {
  late final SqliteCrdt db;
  @override
  Future<void> init() async {
    if (kDebugMode) {
      db = await SqliteCrdt.open(
        (await getBasePath()).getFile('data.db').absolute.path,
        version: 1,
        onCreate: (db, version) async {
          for (final statement
              in (await rootBundle.loadString('assets/db/schema/schema.sql'))
                  .split('--s')) {
            await db.execute(statement);
          }
        },
      );
    }
  }

  @override
  Stream<EntrySaved> getEntries(int page, int limit) {
    return getEntriesSQL(page, limit, '');
  }

  @override
  Stream<EntrySaved> getEntriesSQL(
    int page,
    int limit,
    String sqlfilter,
  ) async* {
    final dbres = await db.query(
      'SELECT * FROM entry WHERE is_deleted = 0 LIMIT ?1 OFFSET ?2',
      [limit, page * limit],
    );
    if (dbres.isEmpty) return;
    for (final e in dbres) {
      yield await constructEntry(
        e,
        locate<SourceExtension>().getExtension(e['extensionid']! as String),
      );
    }
  }

  @override
  Future<EntrySaved?> isSaved(Entry entry) async {
    final dbentry = await db.query(
        'SELECT * FROM entry WHERE id = ?1 AND is_deleted = 0', [entry.id]);
    if (dbentry.isEmpty) return null;
    return await constructEntry(dbentry[0], entry.extension);
  }

  Future<EntrySaved> constructEntry(
    Map<String, Object?> dbentry,
    Extension extension,
  ) async {
    final episodelists = <rust.EpisodeList>[];
    final dbepisodelists = await db
        .query('SELECT * FROM episodelist WHERE entry = ?1', [dbentry['id']]);
    final dbgenres = await db.query(
      'SELECT genre.genre from genre JOIN entryxgenre ON genre.id=entryxgenre.genre WHERE entryxgenre.entry=?',
      [dbentry['id']],
    );
    for (final episodelist in dbepisodelists) {
      final ep = await db.query(
        'SELECT * FROM episode WHERE episodelist = ?1',
        [episodelist['id']],
      );
      if (ep.isEmpty) continue;
      episodelists.add(
        rust.EpisodeList(
          title: episodelist['title']! as String,
          episodes: ep
              .map(
                (e) => rust.Episode(
                  id: e['id']! as String,
                  name: e['name']! as String,
                  url: e['url']! as String,
                  cover: e['cover'] as String?,
                  coverHeader: (json.decode(e['coverheader']! as String)
                          as Map<dynamic, dynamic>)
                      .cast<String, String>(),
                  timestamp: e['timestamp'] as String?,
                ),
              )
              .toList(),
        ),
      );
    }
    final List<EpisodeData> episodedata = List.empty(growable: true);
    final epdatas = await db.query(
      'SELECT * FROM episodedata WHERE entryid = ?1',
      [dbentry['id']! as String],
    );
    for (final epdata in epdatas) {
      episodedata.add(
        EpisodeData(
          bookmark: (epdata['bookmark']! as int) == 1,
          finished: (epdata['finished']! as int) == 1,
          progress: epdata['progress'] as String?,
        ),
      );
    }
    return EntrySavedImpl(
      rust.EntryDetailed(
        id: dbentry['id']! as String,
        url: dbentry['url']! as String,
        title: dbentry['title']! as String,
        status: rust.ReleaseStatus.values
            .firstWhere((e) => e.name == dbentry['status']! as String),
        description: dbentry['description']! as String,
        language: dbentry['language']! as String,
        episodes: episodelists,
        genres: dbgenres.map((e) => e['genre']! as String).toList(),
        alttitles:
            (json.decode(dbentry['alttitles']! as String) as List<dynamic>)
                .cast(),
        author:
            (json.decode(dbentry['author']! as String) as List<dynamic>).cast(),
        cover: dbentry['cover']! as String,
        coverHeader: (json.decode(dbentry['coverheader']! as String)
                as Map<dynamic, dynamic>)
            .cast(),
        mediaType: rust.MediaType.values
            .firstWhere((e) => e.name == (dbentry['mediatype']! as String)),
        rating: dbentry['rating'] as double?,
        views: (dbentry['views'] as int?)?.toDouble(),
        length: dbentry['length'] as int?,
      ),
      extension,
      episodedata,
    );
  }

  @override
  Future<void> removeEntry(EntryDetailed entry) {
    return db.execute('DELETE FROM entry WHERE id=?1', [entry.id]);
  }

  @override
  Future<void> updateEntry(EntryDetailed entry) async {
    await db.transaction((db) async {
      await db.execute(
          'INSERT OR REPLACE INTO entry(id,extensionid,url,title,mediatype,cover,coverheader,author,rating,views,length,ui,status,description,language,alttitles) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16)',
          [
            entry.id,
            entry.extension.id,
            entry.url,
            entry.title,
            entry.mediaType.name,
            entry.cover,
            json.encode(entry.coverHeader ?? {}),
            json.encode(entry.author ?? []),
            entry.rating,
            entry.views,
            entry.length,
            '', //entry.ui,
            entry.status.name,
            entry.description,
            entry.language,
            json.encode(entry.alttitles ?? []),
          ]);
      for (final genre in entry.genres!) {
        await db
            .execute('INSERT OR IGNORE INTO genre(genre) VALUES(?)', [genre]);
        final genreid = (await db
            .query('SELECT id FROM genre WHERE genre = ?', [genre]))[0]['id'];
        await db.execute(
          'INSERT OR IGNORE INTO entryxgenre(entry,genre) VALUES (?,?)',
          [entry.id, genreid],
        );
      }
      for (final episodelist in entry.episodes) {
        await db.execute(
            'INSERT OR REPLACE INTO episodelist(title,entry) VALUES (?,?)', [
          episodelist.title,
          entry.id,
        ]);
        final eplist = await db
            .query('SELECT * FROM episodelist WHERE entry=? AND title=?', [
          entry.id,
          episodelist.title,
        ]);
        for (final episode in episodelist.episodes) {
          await db.execute(
            'INSERT OR REPLACE INTO episode(id,name,url,cover,coverheader,timestamp,episodelist) VALUES (?,?,?,?,?,?,?)',
            [
              episode.id,
              episode.name,
              episode.url,
              episode.cover,
              json.encode(episode.coverHeader ?? {}),
              episode.timestamp,
              eplist[0]['id'],
            ],
          );
        }
      }
      if (entry is EntrySaved) {
        for (final epdata in entry.episodedata.indexed) {
          await db.execute(
            'INSERT OR REPLACE INTO episodedata(entryid,episode,bookmark,finished,progress) VALUES (?,?,?,?,?)',
            [
              entry.id,
              epdata.$1,
              if (epdata.$2.bookmark) 1 else 0,
              if (epdata.$2.finished) 1 else 0,
              epdata.$2.progress,
            ],
          );
        }
      }
    });
    notifyListeners();
  }

  @override
  Future<void> clear() {
    //TODO: implement clear
    throw UnimplementedError();
  }

  @override
  Future<void> merge(String path) {
    // TODO: implement merge
    throw UnimplementedError();
  }
}
