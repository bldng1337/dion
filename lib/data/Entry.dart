import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/sync.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:isar/isar.dart';
import 'package:language_code/language_code.dart';

part 'Entry.g.dart';

extension Mediafunc on MediaType {
  String getAction() {
    return switch (this) {
      MediaType.video => 'Watched',
      MediaType.comic => 'Read',
      MediaType.audio => 'Listened to',
      MediaType.book => 'Read',
      _ => 'Consumed'
    };
  }

  String getEpName({bool multi = false}) {
    return switch (this) {
      MediaType.video => multi ? 'Episode' : 'Episodes',
      MediaType.comic => 'Chapter',
      MediaType.audio => multi ? 'Episode' : 'Episodes',
      MediaType.book => 'Chapter',
      _ => multi ? 'Episode' : 'Episodes'
    };
  }

  IconData icon() {
    return switch (this) {
      MediaType.video => Icons.video_camera_back_outlined,
      MediaType.comic => Icons.image,
      MediaType.audio => Icons.audio_file,
      MediaType.book => Icons.menu_book_sharp,
      _ => Icons.question_mark
    };
  }

  String named() {
    return toString().replaceAll('MediaType.', '');
  }
}

enum MediaType { video, comic, audio, book, unknown }

MediaType getMediaType(String type) {
  return MediaType.values
          .firstWhereOrNull((p0) => p0.toString().contains(type)) ??
      MediaType.unknown;
}

@embedded
class Episode {
  late final String name;
  late final String url;
  late final String weburl;
  late final String? thumbheader;
  late final String? thumbnail;
  DateTime? timestamp;

  Episode();

  Episode.init(
    this.name,
    this.url,
    this.weburl,
    this.thumbnail,
    this.timestamp,
    this.thumbheader,
  );

  factory Episode.fromJson(Map<String, dynamic> jsond) {
    return Episode.init(
      jsond['name'] as String,
      jsond['id'] as String,
      jsond['url'] as String,
      jsond['cover'] as String?,
      DateTime.tryParse((jsond['timestamp'] ?? '') as String),
      json.encode((jsond['coverheader'] as Map<String, dynamic>?) ?? {}),
    );
  }
  Episode clone({String? name, String? url, DateTime? timestamp}) {
    final Episode e = Episode();
    e.name = name ?? this.name;
    e.timestamp = timestamp ?? this.timestamp;
    e.url = url ?? this.url;
    return e;
  }
}

class AEpisodeList {
  late String title;
  late List<Episode> episodes;

  Episode? getEpisode(int index) {
    return episodes[index];
  }
}

@embedded
class EpisodeList extends AEpisodeList {
  EpisodeList();
  EpisodeList.init(String title, List<Episode> episodes) {
    this.title = title;
    this.episodes = episodes;
  }

  factory EpisodeList.fromJson(Map<String, dynamic> json) {
    return EpisodeList.init(
      json['title'] as String,
      (json['episodes'] as List<dynamic>)
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum Status { releasing, complete, unknown }

Status getStatus(String s) {
  return s.toLowerCase().contains('releasing')
      ? Status.releasing
      : Status.complete;
}

class Entry {
  final String title;
  @enumerated
  final MediaType type;
  @Index(unique: true)
  final String url;
  final String weburl;
  final String? cover;
  final String? coverheader;
  final double? rating;
  final String? language;
  final int? views;
  final int? length;
  final List<String>? author;
  final String extname;

  @ignore
  Extension? get ext {
    return ExtensionManager().searchExtension(this);
  }

  Entry(
    this.title,
    this.type,
    this.url,
    this.cover,
    this.rating,
    this.views,
    this.length,
    this.author,
    this.extname,
    this.weburl,
    this.coverheader,
    this.language,
  );

  Future<EntryDetail?> detailed() async {
    final EntrySaved? entry =
        await isar.entrySaveds.where().urlEqualTo(url).findFirst();
    if (entry != null) {
      return entry;
    }
    return ext?.detail(url);
  }

  Future<void> save() async {}

  factory Entry.fromJson(Map<String, dynamic> jsond, Extension ext) {
    return Entry(
      jsond['title'] as String,
      MediaType.values.lastWhere(
        (e) => e.name.toLowerCase() == (jsond['type'] as String).toLowerCase(),
        orElse: () => MediaType.video,
      ),
      jsond['id'] as String,
      jsond['cover'] as String?,
      (jsond['rating'] as num?)?.toDouble(),
      jsond['views'] as int?,
      (jsond['length'] as num?)?.toInt(),
      mlistcast<String>(jsond['author'] as List<dynamic>?),
      ext.indentifier,
      jsond['url'] as String,
      json.encode((jsond['coverheader'] as Map<String, dynamic>?) ?? {}),
      jsond['lang'] as String?,
    );
  }

  EpisodeData getEpdata(int episode) {
    return EpisodeData();
  }

  int getlastReadIndex() {
    return 0;
  }
}

class EntryDetail extends Entry {
  final List<EpisodeList> episodes;
  final List<String> genres;
  @enumerated
  final Status status;
  final String? description;
  final String? extradata;
  int episodeindex = 0; //TODO Save which Source is selected

  @Ignore()
  bool refreshing = false;

  EntryDetail(
    super.title,
    super.type,
    super.url,
    super.cover,
    super.rating,
    super.views,
    super.length,
    super.author,
    super.extname,
    super.weburl,
    this.episodes,
    this.genres,
    this.status,
    this.description,
    this.extradata,
    super.coverheader,
    super.language,
  );

  EntrySaved toSaved() {
    return EntrySaved.fromEntry(this);
  }

  factory EntryDetail.fromJson(Map<String, dynamic> jsond, Extension ext) {
    return EntryDetail(
      jsond['title'] as String,
      MediaType.values.lastWhere(
        (e) => e.name.toLowerCase() == (jsond['type'] as String).toLowerCase(),
        orElse: () => MediaType.video,
      ),
      jsond['id'] as String,
      jsond['cover'] as String?,
      (jsond['rating'] as num?)?.toDouble(),
      (jsond['views'] as num?)?.toInt(),
      (jsond['length'] as num?)?.toInt(),
      mlistcast<String>(jsond['author'] as List<dynamic>?),
      ext.indentifier,
      jsond['url'] as String,
      (jsond['episodes'] as List<dynamic>)
          .map((e) => EpisodeList.fromJson(e as Map<String, dynamic>))
          .toList(),
      listcast<String>((jsond['genres'] ?? []) as List<dynamic>),
      Status.values.lastWhere(
        (e) =>
            e.name.toLowerCase() == (jsond['status'] as String).toLowerCase(),
        orElse: () => Status.releasing,
      ),
      jsond['description'] as String?,
      json.encode(jsond['data'] ?? []),
      json.encode((jsond['coverheader'] as Map<String, dynamic>?) ?? {}),
      jsond['lang'] as String?,
    );
  }

  Future<EntryDetail?> refresh() {
    return detailed();
  }

  void complete(int chapter, {bool date = true}) {}

  Future<Source?> source(AEpisodeList list, int episode) async {
    if (list.episodes.length < episode) {
      return null;
    }
    return await ext!.source(list.episodes[episode], this);
  }
}

@embedded
class EpisodeData {
  bool isBookmarked = false;
  bool completed = false;
  String? sprogress;
  int? iprogress;
  DateTime? readdate;

  void _complete({bool date = true}) {
    completed = true;
    sprogress = null;
    iprogress = null;
    if (date) {
      readdate = DateTime.now();
    }
  }

  void applyJSON(Map<String, dynamic> json) {
    isBookmarked = ((json['isBookmarked'] as bool?) ?? false) || isBookmarked;
    completed = ((json['completed'] as bool?) ?? false) || completed;
    readdate ??= DateTime.tryParse((json['readdate'] as String?) ?? '');
  }

  Map<String, Object> toJSON() {
    return {
      'isBookmarked': isBookmarked,
      'completed': completed,
      if (readdate != null) 'readdate': readdate!.toIso8601String(),
    };
  }
}

@collection
class Category {
  Id id = Isar.autoIncrement;
  final entries = IsarLinks<EntrySaved>();
  @Index(unique: true)
  String name = '';

  //TODO: Category Filter
}

@collection
class EntrySaved extends EntryDetail {
  Id id = Isar.autoIncrement;
  List<EpisodeData?> epdata = List.empty(growable: true);

  EntrySaved(
    super.title,
    super.type,
    super.url,
    super.cover,
    super.rating,
    super.views,
    super.length,
    super.author,
    super.extname,
    super.weburl,
    super.episodes,
    super.genres,
    super.status,
    super.description,
    super.extradata,
    super.coverheader,
    super.language,
  );
  //Download
  String getDownloadpath(AEpisodeList list, int episode) {
    return 'downloads/${encodeFilename(extname)}/${encodeFilename(url)}/${encodeFilename(list.title)}/$episode';
  }

  Future<Directory> getDir(AEpisodeList list, int episode) async {
    return await getPath(getDownloadpath(list, episode), create: false);
  }

  Future<bool> isDownloaded(AEpisodeList list, int episode) async {
    return (await getDir(list, episode)).exists();
  }

  Future<List<TaskRecord>> getDownloads(AEpisodeList list, int episode) async {
    return await FileDownloader()
        .database
        .allRecords(group: getDownloadpath(list, episode));
  }

  Future<bool> download(AEpisodeList list, int episode) async {
    final Directory dir = await getDir(list, episode);
    // if (await dir.exists()) {TODO: Clean dir
    // }
    //TODO check wifi
    final Episode? e = list.getEpisode(episode);
    if (e == null) {
      return false;
    }
    final Source? s = await source(list, episode);
    if (s == null) {
      return false;
    }
    final SourceMeta sm = s.getdownload();
    final File fn = dir.getFile('meta.json');
    await fn.create(recursive: true);
    await fn.writeAsString(json.encode({...sm.data, 'name': sm.name}));
    for (final f in sm.files) {
      if (f.isdata) {
        final File fn = dir.getFile(f.filename);
        if (await fn.exists()) {
          await fn.delete();
        }
        fn.create(recursive: true);
        fn.writeAsBytes(f.data!.toList());
      } else {
        final task = DownloadTask(
          url: f.url!,
          filename: f.filename,
          group: getDownloadpath(list, episode),
          displayName: e.name,
          directory: 'dion/${getDownloadpath(list, episode)}',
          requiresWiFi: true,
          allowPause: true,
          updates: Updates.statusAndProgress,
        );
        await FileDownloader().enqueue(task);
      }
    }
    return true;
  }

  Future<void> delete(AEpisodeList list, int episode) async {
    final Directory dir = await getDir(list, episode);
    await dir.delete(recursive: true);
  }

  @Backlink(to: 'entries')
  final category = IsarLinks<Category>();

  int get episodescompleted {
    return epdata
        .where((element) => element != null && element.completed)
        .length;
  }

  int get totalepisodes {
    return episodes[episodeindex]
        // .reduce(
        //   (value, element) =>
        //       value.episodes.length > element.episodes.length ? value : element,
        // )
        .episodes
        .length;
  }

  int get episodesnotcompleted {
    return totalepisodes - episodescompleted;
  }

  @override
  EpisodeData getEpdata(int episode) {
    if (epdata.length <= episode) {
      epdata = List.from(epdata);
      epdata
          .addAll(Iterable.generate(episode - epdata.length + 1, (i) => null));
    }
    if (epdata[episode] == null) {
      epdata[episode] = EpisodeData();
    }
    return epdata[episode]!;
  }

  @override
  void complete(int chapter, {bool date = true}) {
    if (date) {
      makeconsumeActivity(this, [chapter], ReadType.read);
    }
    getEpdata(chapter)._complete(date: date);
  }

  @override
  Future<void> save() async {
    await isar.writeTxn(() async {
      isar.entrySaveds.put(this);
    });
    await savesync();
  }

  @override
  int getlastReadIndex() {
    return min(
      epdata.lastIndexWhere((element) => element?.completed ?? false) + 1,
      epdata.length - 1,
    );
  }

  @override
  Future<EntryDetail?> refresh() async {
    refreshing = true;
    final ext=this.ext!;
    bool shoulddisable=false;
    if(!ext.enabled){
      shoulddisable=true;
      await ext.setenabled(true);
    }
    final EntryDetail? entryref = await ext?.detail(url);
    if (entryref != null) {
      final EntrySaved newentry = EntrySaved.fromEntry(entryref);
      newentry.id = id;
      newentry.epdata = epdata;
      newentry.episodeindex=episodeindex;
      await newentry.save();
      refreshing = false;
      if(shoulddisable){
        await ext.setenabled(false);
      }
      return newentry;
    }
    refreshing = false;
    if(shoulddisable){
      await ext.setenabled(false);
    }
    return this;
  }

  @override
  Future<Source?> source(AEpisodeList list, int episode) async {
    if (list.episodes.length < episode) {
      return null;
    }
    if (await isDownloaded(list, episode)) {
      final Source? s = await Source.resolve(this, list, episode);
      if (s == null) {
        delete(list, episode);
      }
      return s;
    }
    return ext!.source(list.episodes[episode], this);
  }

  @override
  Future<EntryDetail?> detailed() {
    return Future.value(this);
  }

  Future<EntryDetail?> toEntryDetailed() async {
    return EntryDetail(
      title,
      type,
      url,
      cover,
      rating,
      views,
      length,
      author,
      extname,
      weburl,
      episodes,
      genres,
      status,
      description,
      extradata,
      coverheader,
      language,
    );
  }

  factory EntrySaved.fromEntry(EntryDetail e) {
    return EntrySaved(
      e.title,
      e.type,
      e.url,
      e.cover,
      e.rating,
      e.views,
      e.length,
      e.author,
      e.extname,
      e.weburl,
      e.episodes,
      e.genres,
      e.status,
      e.description,
      e.extradata,
      e.coverheader,
      e.language,
    );
  }

  Map<String, dynamic> toJSON() {
    final Map<String, dynamic> mjson = {};
    final List<Category> cat = category.toList();
    mjson['url'] = url;
    mjson['extname'] = extname;
    final Map<int, EpisodeData?> data = Map.from(epdata.asMap());
    data.removeWhere((key, value) => value == null);
    mjson['epdata'] = Map.from(
      data.map((key, value) => MapEntry(key.toString(), value!.toJSON())),
    );
    mjson['categories'] = List.generate(cat.length, (index) => cat[index].name);
    return mjson;
  }
}
