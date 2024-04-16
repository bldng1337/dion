import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/Utils/file_utils.dart';
import 'package:dionysos/Utils/utils.dart';
import 'package:dionysos/activity.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:isar/isar.dart';

part 'Entry.g.dart';

extension Mediafunc on MediaType {
  IconData icon() {
    return switch (this) {
      MediaType.video => Icons.video_camera_back_outlined,
      MediaType.comic => Icons.image,
      MediaType.audio => Icons.audio_file,
      MediaType.book => Icons.menu_book_sharp,
    };
  }
  named() {
    return toString().replaceAll("MediaType.", "");
  }
}

enum MediaType {
  video,
  comic,
  audio,
  book,
}

MediaType getMediaType(String type) {
  return MediaType.values
          .firstWhereOrNull((p0) => p0.toString().contains(type)) ??
      MediaType.video;
}

@embedded
class Episode {
  late final String name;
  late final String url;
  DateTime? timestamp;

  Episode();

  Episode.init(this.name, this.url);

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode.init(json['name'], json['url']);
  }
  Episode clone({String? name, String? url, DateTime? timestamp}) {
    Episode e = Episode();
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

/// Represents a downloaded list of episodes for a specific entry.
/// Contains information about the downloaded episodes, such as their titles and URLs.
/// Provides methods to refresh the downloaded episode list and manage the download settings.
// @embedded
// class EpisodeListDownloaded extends AEpisodeList {
//   @ignore
//   Map<int, Episode> downloaded = {};
//   int dependentIndex = 0;
//   bool autodownload = false;
//   int predownloadChapters = 1;
//   bool autodelete = false;
//   int chapterDelete = 1;

//   @override
//   Episode? getEpisode(int index) {
//     return downloaded[index] ?? episodes[index];
//   }

//   /// Refreshes the downloaded episode list based on the given saved entry.
//   /// If the saved entry has fewer episodes than the dependent index,
//   /// the title and episodes of the downloaded list will be set to "Unknown" and an empty list, respectively.
//   /// Otherwise, the title will be set to the title of the dependent episode list appended with " - Download",
//   /// and the episodes will be set to the episodes of the dependent episode list.
//   ///
//   /// @param saved The saved entry to refresh the downloaded episode list from.
//   Future<void> refresh(EntrySaved saved) async {
//     if (saved.episodes.length < dependentIndex) {
//       title = "Unknown";
//       episodes = [];
//     } else {
//       title = "${saved.episodes[dependentIndex].title} - Download";
//       episodes = saved.episodes[dependentIndex].episodes;
//     }
//     await checkdownloads(saved);
//   }

//   Future<void> delete(int episode, EntrySaved saved) async {
//     if (isDownloaded(episode)) {
//       String spath =
//           "downloads/${encodeFilename(saved.extname)}/${encodeFilename(saved.url)}/$episode";
//       await (await getPath(spath)).delete(recursive: true);
//       downloaded.remove(episode);
//     }
//   }

//   Future<bool> download(int episode, EntrySaved saved) async {
//     if (episodes.length < episode) {
//       return false;
//     }
//     if (isDownloaded(episode)) {
//       return true;
//     }
//     //TODO check wifi
//     Episode e = episodes[episode];
//     Source? s = await saved.source(e);
//     if (s == null) {
//       return false;
//     }
//     String path =
//         "downloads/${encodeFilename(saved.extname)}/${encodeFilename(saved.url)}/${episode}";
//     SourceMeta sm = s.getdownload();
//     File fn = (await getPath(path)).getFile("meta.json");
//     if (await fn.exists()) {
//       await fn.delete();
//     }
//     fn.create(recursive: true);
//     fn.writeAsString(json.encode({...sm.data, "name": sm.name}));
//     for (var f in sm.files) {
//       if (f.isdata) {
//         File fn = (await getPath(path)).getFile(f.filename);
//         if (await fn.exists()) {
//           await fn.delete();
//         }
//         fn.create(recursive: true);
//         fn.writeAsBytes(f.data!.toList());
//       } else {
//         print(f.url!);
//         final task = DownloadTask(
//             url: f.url!,
//             filename: f.filename,
//             group: encodeFilename(saved.url + e.url),
//             displayName: episodes[episode].name,
//             directory: "dion/$path",
//             requiresWiFi: true,
//             allowPause: true,
//             updates: Updates.statusAndProgress,
//             baseDirectory: BaseDirectory.applicationDocuments);
//         await FileDownloader().enqueue(task);
//       }
//     }
//     return true;
//   }

//   Future<List<TaskRecord>> getDownloads(int episode, EntrySaved saved) async {
//     if (episodes.length < episode) {
//       return [];
//     }
//     Episode e = episodes[episode];
//     return await FileDownloader()
//         .database
//         .allRecords(group: encodeFilename(saved.url + e.url));
//   }

//   bool isDownloaded(int index) {
//     return downloaded.containsKey(index);
//   }

//   Future<void> checkdownloads(EntrySaved saved) async {
//     if (autodownload) {
//       for (int i = saved.getlastReadIndex();
//           i < saved.getlastReadIndex() + predownloadChapters;
//           i++) {
//         await download(i, saved);
//       }
//     }
//     if (autodelete) {
//       for (int i = 0; i < saved.getlastReadIndex() - chapterDelete; i++) {
//         await delete(i, saved);
//       }
//     }
//     String spath =
//         "downloads/${encodeFilename(saved.extname)}/${encodeFilename(saved.url)}";
//     Directory d = await getPath(spath);
//     Map<int, Episode> newdownloaded = {};
//     print("Searching $spath");
//     await for (final file in d.list()) {
//       if (file is Directory) {
//         print("checking ${file.path}");
//         Directory d = file;
//         int index = int.parse(d.name);
//         if (episodes.length < index) {
//           continue;
//         }
//         newdownloaded[index] = episodes[index].clone(url: "local:${d.path}");
//         print("Found ${newdownloaded[index]!.name}");
//       }
//     }
//     print("replacing");
//     downloaded = newdownloaded;
//     print("Download ${downloaded.length}");
//   }
// }

class DownloadUtils{
  static String getDownloadpath(EntrySaved saved,AEpisodeList list, int episode){
    return "downloads/${encodeFilename(saved.extname)}/${encodeFilename(saved.url)}/${encodeFilename(list.title)}/$episode";
  }
  static Future<Directory> getDownloadDir(EntrySaved saved,AEpisodeList list, int episode) async {
    Directory d = await getPath(getDownloadpath(saved,list,episode),create: false);
    return d;
  }

  static Future<List<TaskRecord>> getDownloads(EntrySaved saved,AEpisodeList list, int episode) async {
    return await FileDownloader()
        .database
        .allRecords(group: getDownloadpath(saved,list,episode));
  }

  static Future<bool> download(EntrySaved saved,AEpisodeList list, int episode) async {
    print("Downloading ${list.getEpisode(episode)?.name}");
    Directory dir=await getDownloadDir(saved,list,episode);
    // if (await dir.exists()) {TODO: Clean dir
    // }
    //TODO check wifi
    Episode? e = list.getEpisode(episode);
    if(e==null){
      return false;
    }
    Source? s = await saved.source(list,episode);
    if (s == null) {
      return false;
    }
    SourceMeta sm = s.getdownload();
    File fn = dir.getFile("meta.json");
    await fn.create(recursive: true);
    await fn.writeAsString(json.encode({...sm.data, "name": sm.name}));
    for (var f in sm.files) {
      if (f.isdata) {
        File fn = dir.getFile(f.filename);
        if (await fn.exists()) {
          await fn.delete();
        }
        fn.create(recursive: true);
        fn.writeAsBytes(f.data!.toList());
      } else {
        print("Downloading file ${f.url!}");
        final task = DownloadTask(
            url: f.url!,
            filename: f.filename,
            group: getDownloadpath(saved,list,episode),
            displayName: e.name,
            directory: "dion/${getDownloadpath(saved,list,episode)}",
            requiresWiFi: true,
            allowPause: true,
            updates: Updates.statusAndProgress,
            baseDirectory: BaseDirectory.applicationDocuments);
        await FileDownloader().enqueue(task);
      }
    }
    return true;
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
        json['title'],
        (json['episodes'] as List<dynamic>)
            .map((e) => Episode.fromJson(e))
            .toList());
  }
}

enum Status {
  releasing,
  complete,
}

Status getStatus(String s) {
  return s.toLowerCase().contains("releasing")
      ? Status.releasing
      : Status.complete;
}

class Entry {
  final String title;
  @enumerated
  final MediaType type;
  @Index(unique: true)
  final String url;
  final String? cover;
  final double? rating;
  final int? views;
  final int? length;
  final List<String>? author;
  final String extname;

  @ignore
  Extension? get ext {
    return ExtensionManager().searchExtension(this);
  }

  Entry(this.title, this.type, this.url, this.cover, this.rating, this.views,
      this.length, this.author, this.extname);

  Future<EntryDetail?> detailed() async {
    EntrySaved? entry =
        await isar.entrySaveds.where().urlEqualTo(url).findFirst();
    if (entry != null) {
      return entry;
    }
    return ext?.detail(url);
  }

  save() {}

  factory Entry.fromJson(Map<String, dynamic> json, Extension ext) {
    return Entry(
        json['title'] as String,
        MediaType.values.lastWhere(
            (e) =>
                e.name.toLowerCase() == (json['type'] as String).toLowerCase(),
            orElse: () => MediaType.video),
        json['url'] as String,
        json['cover'] as String?,
        (json['rating'] as num?)?.toDouble(),
        json['views'] as int?,
        (json['length'] as num?)?.toInt(),
        mlistcast<String>(json['author'] as List<dynamic>?),
        ext.indentifier);
  }

  EpisodeData getEpdata(int episode) {
    return EpisodeData();
  }

  getlastReadIndex() {
    return 0;
  }
}

class EntryDetail extends Entry {
  final List<EpisodeList> episodes;
  final List<String> genres;
  @enumerated
  final Status status;
  final String? description;
  int episodeindex = 0;

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
    this.episodes,
    this.genres,
    this.status,
    this.description,
  );

  EntrySaved toSaved() {
    return EntrySaved.fromEntry(this);
  }

  factory EntryDetail.fromJson(Map<String, dynamic> json, Extension ext) {
    return EntryDetail(
      json['title'] as String,
      MediaType.values.lastWhere(
          (e) => e.name.toLowerCase() == (json['type'] as String).toLowerCase(),
          orElse: () => MediaType.video),
      json['url'] as String,
      json['cover'] as String?,
      (json['rating'] as num?)?.toDouble(),
      (json['views'] as num?)?.toInt(),
      (json['length'] as num?)?.toInt(),
      mlistcast<String>(json['author'] as List<dynamic>?),
      ext.indentifier,
      (json['episodes'] as List<dynamic>)
          .map((e) => EpisodeList.fromJson(e))
          .toList(),
      listcast<String>(json['genres'] as List<dynamic>),
      Status.values.lastWhere(
          (e) =>
              e.name.toLowerCase() == (json['status'] as String).toLowerCase(),
          orElse: () => Status.releasing),
      json['description'] as String?,
    );
  }

  Future<EntryDetail?> refresh() {
    return detailed();
  }

  void complete(int chapter, {bool date = true}) {}

  Future<Source?> source(AEpisodeList list, int episode) async {
    if (list.episodes.length<episode) {
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

  _complete({date = true}) {
    completed = true;
    sprogress = null;
    iprogress = null;
    if (date) {
      readdate = DateTime.now();
    }
  }

  int getIProgress(int def) {
    iprogress ??= def;
    return iprogress ?? def;
  }

  String getSProgress(String def) {
    sprogress ??= def;
    return sprogress ?? def;
  }

  applyJSON(json) {
    isBookmarked = ((json["isBookmarked"] as bool?) ?? false) || isBookmarked;
    completed = ((json["completed"] as bool?) ?? false) || completed;
    readdate ??= DateTime.tryParse(json["readdate"] ?? "");
  }

  toJSON() {
    return {
      "isBookmarked": isBookmarked,
      "completed": completed,
      if (readdate != null) "readdate": readdate!.toIso8601String(),
    };
  }
}

@collection
class Category {
  Id id = Isar.autoIncrement;
  final entries = IsarLinks<EntrySaved>();
  @Index(unique: true)
  String name = "";

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
      super.episodes,
      super.genres,
      super.status,
      super.description);


  Future<Directory> getDir(AEpisodeList list,int episode){
    return DownloadUtils.getDownloadDir(this,list, episode);
  }
  Future<bool> isDownloaded(AEpisodeList list,int episode) async {
    return (await DownloadUtils.getDownloadDir(this,list, episode)).exists();
  }
  Future<List<TaskRecord>> getDownloads(AEpisodeList list,int episode){
    return DownloadUtils.getDownloads(this, list, episode);
  }
  Future<bool> download(AEpisodeList list,int episode){
    return DownloadUtils.download(this, list, episode);
  }

  Future<void> delete(AEpisodeList list,int episode) async{
    Directory dir=await getDir(list, episode);
    await dir.delete(recursive: true);
  }

  // List<EpisodeListDownloaded> download = List.empty(growable: true);
  // final List<EpisodeList> generated; TODO

  @Backlink(to: 'entries')
  final category = IsarLinks<Category>();

  int get episodescompleted {
    return epdata
        .where((element) => element != null && element.completed)
        .length;
  }

  int get totalepisodes {
    return episodes
        .reduce((value, element) =>
            value.episodes.length > element.episodes.length ? value : element)
        .episodes
        .length;
  }

  int get episodesnotcompleted {
    return totalepisodes - episodescompleted;
  }

  @override
  EpisodeData getEpdata(int episode) {
    if (epdata.length <= episode) {
      epdata = List.from(epdata, growable: true);
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
  save() {
    isar.writeTxn(() async {
      isar.entrySaveds.put(this);
    });
    savesync();
  }

  @override
  int getlastReadIndex() {
    return min(
        epdata.lastIndexWhere((element) => element?.completed ?? false) + 1,
        epdata.length - 1);
  }

  @override
  Future<EntryDetail?> refresh() async {
    refreshing = true;
    EntryDetail? entryref = await ext?.detail(url);
    if (entryref != null) {
      EntrySaved newentry = EntrySaved.fromEntry(entryref);
      newentry.id = id;
      newentry.epdata = epdata;
      newentry.save();
      refreshing = false;
      return newentry;
    }
    refreshing = false;
    return this;
  }

  @override
  Future<Source?> source(AEpisodeList list, int episode) async {
    if (list.episodes.length<episode) {
      return null;
    }
    if(await isDownloaded(list, episode)){
      Source? s=await Source.resolve(this,list, episode);
      if(s==null){
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
    return EntryDetail(title, type, url, cover, rating, views, length, author,
        extname, episodes, genres, status, description);
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
        e.episodes,
        e.genres,
        e.status,
        e.description);
  }

  toJSON() {
    Map<String, dynamic> mjson = {};
    List<Category> cat = category.toList();
    mjson["url"] = url;
    mjson["extname"] = extname;
    Map<int, EpisodeData?> data = Map.from(epdata.asMap());
    data.removeWhere((key, value) => value == null);
    mjson["epdata"] = Map.from(
        data.map((key, value) => MapEntry(key.toString(), value!.toJSON())));
    mjson["categories"] = List.generate(cat.length, (index) => cat[index].name);
    return mjson;
  }
}
