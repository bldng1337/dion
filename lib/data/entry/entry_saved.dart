import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class EpisodeData {
  bool bookmark;
  bool finished;
  String? progress;
  EpisodeData({required this.bookmark, required this.finished, this.progress});
  EpisodeData.empty() : this(bookmark: false, finished: false, progress: null);

  @override
  bool operator ==(Object other) =>
      other is EpisodeData &&
      bookmark == other.bookmark &&
      finished == other.finished &&
      progress == other.progress;

  @override
  int get hashCode => bookmark.hashCode ^ finished.hashCode ^ progress.hashCode;

  @override
  String toString() {
    return 'EpisodeData{bookmark: $bookmark, finished: $finished, progress: $progress}';
  }

  Map<String, dynamic> toJson() {
    return {'bookmark': bookmark, 'finished': finished, 'progress': progress};
  }

  factory EpisodeData.fromJson(Map<String, dynamic> json) {
    return EpisodeData(
      bookmark: json['bookmark'] as bool,
      finished: json['finished'] as bool,
      progress: json['progress'] as String?,
    );
  }
}

class EntrySavedSettings {
  Setting<bool, SettingMetaData> reverse;
  Setting<bool, SettingMetaData> hideFinishedEpisodes;
  Setting<bool, SettingMetaData> onlyShowBookmarked;

  Setting<int, SettingMetaData> downloadNextEpisodes;
  Setting<bool, SettingMetaData> deleteOnFinish;

  EntrySavedSettings({
    bool? reverse,
    bool? hideFinishedEpisodes,
    int? downloadNextEpisodes,
    bool? deleteOnFinish,
    bool? onlyShowBookmarked,
  }) : reverse = Setting(reverse ?? false, const SettingMetaData()),
       hideFinishedEpisodes = Setting(
         hideFinishedEpisodes ?? false,
         const SettingMetaData(),
       ),
       onlyShowBookmarked = Setting(
         onlyShowBookmarked ?? false,
         const SettingMetaData(),
       ),
       downloadNextEpisodes = Setting(
         downloadNextEpisodes ?? 0,
         const SettingMetaData(),
       ),
       deleteOnFinish = Setting(
         deleteOnFinish ?? false,
         const SettingMetaData(),
       );

  factory EntrySavedSettings.defaultSettings() {
    return EntrySavedSettings();
  }

  factory EntrySavedSettings.fromJson(dynamic json) {
    if (json == null) return EntrySavedSettings.defaultSettings();
    return EntrySavedSettings(
      reverse: json['reverse'] as bool,
      hideFinishedEpisodes: json['hideFinishedEpisodes'] as bool,
      downloadNextEpisodes: json['downloadNextEpisodes'] as int,
      deleteOnFinish: json['deleteOnFinish'] as bool,
      onlyShowBookmarked: json['onlyShowBookmarked'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reverse': reverse.value,
      'hideFinishedEpisodes': hideFinishedEpisodes.value,
      'downloadNextEpisodes': downloadNextEpisodes.value,
      'deleteOnFinish': deleteOnFinish.value,
      'onlyShowBookmarked': onlyShowBookmarked.value,
    };
  }
}

class EntrySaved with DBConstClass, DBModifiableClass implements EntryDetailed {
  @override
  String boundExtensionId;
  rust.EntryDetailed entry;

  List<Category> categories;
  @override
  Map<String, rust.Setting> extensionSettings;
  EntrySavedSettings savedSettings;

  List<EpisodeData> _episodedata;
  int episode;

  EntrySaved({
    required this.entry,
    required this.categories,
    required List<EpisodeData> episodedata,
    required this.boundExtensionId,
    required this.episode,
    required this.savedSettings,
    required this.extensionSettings,
  }) : _episodedata = episodedata;

  List<EpisodeData> get episodedata => _episodedata;
  int get latestEpisode => min(
    episodedata.lastIndexWhere((e) => e.finished == true) + 1,
    totalEpisodes,
  );
  int get totalEpisodes => episodes.length;
  EpisodeData getEpisodeData(int episode) {
    if (episodedata.length > episode) {
      return episodedata[episode];
    }
    _episodedata = List.generate(episode + 1, (index) {
      if (episodedata.length > index) {
        return episodedata[index];
      }
      return EpisodeData.empty();
    });
    return _episodedata[episode];
  }

  void setSetting(String key, dynamic value) {
    final setting = extensionSettings[key];
    if (setting == null) return;
    extensionSettings[key] = setting.copyWith(
      value: setting.value.updateWith(value),
    );
  }

  rust.Setting? getSetting(String key) {
    return extensionSettings[key];
  }

  List<Setting<dynamic, EntrySettingMetaData<dynamic>>> get extsettings {
    return extensionSettings.entries.map((e) {
      final meta = EntrySettingMetaData(
        this,
        e.key,
        e.value.label,
        e.value.visible,
        e.value.ui,
      );
      return Setting.fromValue(
        e.value.default_.data as dynamic,
        e.value.value.data,
        meta,
      );
    }).toList();
  }

  @override
  EntryId get id => entry.id;
  @override
  String get url => entry.url;
  @override
  String get title => entry.titles.first;
  @override
  List<String>? get titles => entry.titles;
  @override
  MediaType get mediaType => entry.mediaType;
  @override
  Link? get cover => entry.cover;
  @override
  List<String>? get author => entry.author;
  @override
  double? get rating => entry.rating;
  @override
  double? get views => entry.views;
  @override
  int? get length => entry.length;
  @override
  CustomUI? get ui => entry.ui;
  @override
  rust.ReleaseStatus get status => entry.status;
  @override
  String get description => entry.description;
  @override
  String get language => entry.language;
  @override
  List<Episode> get episodes => entry.episodes;
  @override
  List<String>? get genres => entry.genres;
  @override
  Extension? get extension =>
      locate<SourceExtension>().tryGetExtension(boundExtensionId);

  @override
  FutureOr<EntryDetailed> toDetailed({rust.CancelToken? token}) {
    return this;
  }

  @override
  FutureOr<EntrySaved> toSaved() {
    return this;
  }

  @override
  FutureOr<EntryDetailed> refresh({CancelToken? token}) async {
    await locate<SourceExtension>().detail(this, token: token);
    await save();
    return this;
  }

  Future<void> save() async {
    await locate<Database>().updateEntry(this);
  }

  Future<void> delete() async {
    await locate<Database>().removeEntry(this);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': entrySerializeVersion.current,
      'entry': entry.toJson(),
      'extensionid': boundExtensionId,
      'episodedata': episodedata,
      'episode': episode,
      'categories': categories.map((e) => e.id).toList(),
      'savedSettings': savedSettings.toJson(),
      'extensionSettings': extensionSettings.map((key, value) {
        return MapEntry(key, value.toJson());
      }),
    };
  }

  static Future<EntrySaved> fromJson(Map<String, dynamic> json) async {
    final db = locate<Database>();
    switch (json['version']) {
      case 1:
        return EntrySaved(
          entry: rust.EntryDetailed(
            id: EntryId(uid: json['entry']['id'] as String),
            url: json['entry']['url'] as String,
            author: (json['entry']['author'] as List<dynamic>?)?.cast(),
            cover: Link(
              url: json['entry']['cover'] as String,
              header: (json['entry']['coverHeader'] as Map<String, dynamic>?)
                  ?.cast(),
            ),
            genres: (json['entry']['genres'] as List<dynamic>?)?.cast(),
            length: json['entry']['length'] as int?,
            meta: (json['entry']['meta'] as Map<String, dynamic>?)?.cast(),
            rating: json['entry']['rating'] as double?,
            views: json['entry']['views'] as double?,
            titles: [json['entry']['title'] as String],
            mediaType: JsonMediaType.fromJson(json['entry']['mediaType']),
            status: JsonReleaseStatus.fromJson(json['entry']['status']),
            description: json['entry']['description'] as String,
            language: json['entry']['language'] as String,
            episodes: (json['entry']['episodes'] as List<dynamic>)
                .map(
                  (ep) => Episode(
                    id: EpisodeId(uid: ep['id'] as String),
                    name: ep['name'] as String,
                    url: ep['url'] as String,
                    cover: ep['cover'] != null
                        ? Link(
                            url: ep['cover'] as String,
                            header: (ep['coverheader'] as Map<String, dynamic>?)
                                ?.cast(),
                          )
                        : null,
                    description: ep['description'] as String?,
                    timestamp: ep['timestamp'] as String?,
                  ),
                )
                .toList(),
          ),
          categories: await db.getCategoriesbyId(
            fromDynamic((json['categories'] as List<dynamic>?) ?? []).toList(),
          ),
          episodedata:
              (json['episodedata'] as List<dynamic>?)
                  ?.map((e) => EpisodeData.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
          boundExtensionId: json['extensionid'] as String,
          episode: (json['episode'] as int?) ?? 0,
          savedSettings: EntrySavedSettings.fromJson(json['settings']),
          extensionSettings: {},
        );
    }
    return EntrySaved(
      entry: rust.JsonEntryDetailed.fromJson(
        json['entry'] as Map<String, dynamic>,
      ),
      categories: await db.getCategoriesbyId(
        fromDynamic((json['categories'] as List<dynamic>?) ?? []).toList(),
      ),
      episodedata:
          (json['episodedata'] as List<dynamic>?)
              ?.map((e) => EpisodeData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      boundExtensionId: json['extensionid'] as String,
      episode: (json['episode'] as int?) ?? 0,
      savedSettings: EntrySavedSettings.fromJson(json['savedSettings']),
      extensionSettings:
          (json['extensionSettings'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              rust.JsonSetting.fromJson(value as Map<String, dynamic>),
            ),
          ) ??
          {},
    );
  }

  @override
  Map<String, dynamic> toEntryJson() {
    return {
      'version': entrySerializeVersion.current,
      'type': 'entry',
      'boundExtensionId': boundExtensionId,
      'entry': rust.Entry(
        id: entry.id,
        url: entry.url,
        title: entry.titles.first,
        mediaType: entry.mediaType,
        cover: entry.cover,
        author: entry.author,
        rating: entry.rating,
        views: entry.views,
        length: entry.length,
      ).toJson(),
    };
  }

  @override
  DBRecord get dbId => constructEntryDBRecord(this);

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    return toJson();
  }
}

DBRecord constructEntryDBRecord(Entry entry) => DBRecord(
  'entry',
  base64.encode(utf8.encode('${entry.id.uid}_${entry.boundExtensionId}')),
);

Iterable<DBRecord> fromDynamic(Iterable<dynamic> list) {
  return list.map(
    (e) => e is DBRecord ? e : DBRecord.fromJson(e as Map<String, dynamic>),
  );
}
