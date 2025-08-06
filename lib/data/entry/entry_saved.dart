import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/extension_setting.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:flutter_surrealdb/flutter_surrealdb.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class EntrySettingMetaData<T> extends SettingMetaData<T>
    implements ExtensionSettingMetaData<T> {
  final EntrySaved entry;
  final String settingkey;
  const EntrySettingMetaData(this.entry, this.settingkey);

  @override
  void onChange(T val) {
    entry.setSetting(settingkey, val);
  }

  @override
  String get id => settingkey;

  @override
  rust.Setting get setting => entry._getSetting(settingkey)!;

  @override
  List<EnumValue<T>> get values => switch (setting.ui) {
    final rust.SettingUI_Dropdown dropdown =>
      dropdown.options.map((e) => EnumValue(e.label, e.value as T)).toList(),
    _ => throw UnimplementedError(
      'Settingvalue conversion for $runtimeType not implemented',
    ),
  };
  @override
  String getLabel(T value) => switch (setting.ui) {
    final rust.SettingUI_Dropdown dropdown =>
      dropdown.options.firstWhere((e) => e.value == value).label,
    _ => throw UnimplementedError(
      'Settingvalue conversion for $runtimeType not implemented',
    ),
  };
}

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
    };
  }
}

class EntrySaved with DBConstClass, DBModifiableClass implements EntryDetailed {
  @override
  final Extension extension;
  rust.EntryDetailed entry;

  List<Category> categories;
  EntrySavedSettings settings;

  List<EpisodeData> _episodedata;
  int episode;

  EntrySaved({
    required this.entry,
    required this.categories,
    required List<EpisodeData> episodedata,
    required this.extension,
    required this.episode,
    required this.settings,
  }) : _episodedata = episodedata;

  factory EntrySaved.fromEntryDetailed(EntryDetailedImpl entry) {
    return EntrySaved(
      entry: entry.entry,
      categories: [],
      episodedata: [],
      extension: entry.extension,
      episode: 0,
      settings: EntrySavedSettings.defaultSettings(),
    );
  }

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
    if (rawsettings == null) return;
    final setting = rawsettings![key];
    if (setting == null) return;
    final newsettings = {
      ...rawsettings!,
      key: setting.copyWith(val: setting.val.updateWith(value)),
    };
    entry = entry.copyWith(settings: newsettings);
  }

  rust.Setting? _getSetting(String key) {
    return entry.settings?[key];
  }

  List<Setting<dynamic, EntrySettingMetaData<dynamic>>> get extsettings {
    if (rawsettings == null) return [];
    return rawsettings!.entries
        .map((e) => e.value.toSetting(EntrySettingMetaData(this, e.key)))
        .toList();
  }

  @override
  String get id => entry.id;
  @override
  String get url => entry.url;
  @override
  String get title => entry.title;
  @override
  MediaType get mediaType => entry.mediaType;
  @override
  String? get cover => entry.cover;
  @override
  Map<String, String>? get coverHeader => entry.coverHeader;
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
  List<String>? get alttitles => entry.alttitles;

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
    await locate<SourceExtension>().update(this, token: token);
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
      'extensionid': extension.id,
      'episodedata': episodedata,
      'episode': episode,
      'categories': categories.map((e) => e.id).toList(),
    };
  }

  static Future<EntrySaved> fromJson(Map<String, dynamic> json) async {
    final exts = locate<SourceExtension>();
    final db = locate<Database>();
    return EntrySaved(
      entry: rust.EntryDetailed.fromJson(json['entry'] as Map<String, dynamic>),
      categories: await db.getCategory(
        fromDynamic((json['categories'] as List<dynamic>?) ?? []).toList(),
      ),
      episodedata:
          (json['episodedata'] as List<dynamic>?)
              ?.map((e) => EpisodeData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      extension: exts.getExtension(json['extensionid'] as String),
      episode: (json['episode'] as int?) ?? 0,
      settings: EntrySavedSettings.fromJson(json['settings']),
    );
  }

  @override
  Map<String, dynamic> toEntryJson() {
    return {
      'version': entrySerializeVersion.current,
      'type': 'entry',
      'entry': rust.Entry(
        id: entry.id,
        url: entry.url,
        title: entry.title,
        mediaType: entry.mediaType,
        cover: entry.cover,
        coverHeader: entry.coverHeader,
        author: entry.author,
        rating: entry.rating,
        views: entry.views,
        length: entry.length,
      ).toJson(),
      'extensionid': extension.id,
    };
  }

  @override
  DBRecord get dbId => constructEntryDBRecord(this);

  Map<String, rust.Setting>? get rawsettings => entry.settings;

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    return toJson();
  }
}

DBRecord constructEntryDBRecord(Entry entry) => DBRecord(
  'entry',
  base64.encode(utf8.encode('${entry.id}_${entry.extension.id}')),
);

Iterable<DBRecord> fromDynamic(Iterable<dynamic> list) {
  return list.map(
    (e) => e is DBRecord ? e : DBRecord.fromJson(e as Map<String, dynamic>),
  );
}
