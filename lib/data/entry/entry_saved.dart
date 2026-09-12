import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/json_patch.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/release_prediction.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class SavedQuote {
  final String text;
  final DateTime savedAt;

  const SavedQuote({required this.text, required this.savedAt});

  @override
  bool operator ==(Object other) =>
      other is SavedQuote && text == other.text && savedAt == other.savedAt;

  @override
  int get hashCode => Object.hash(text, savedAt);

  @override
  String toString() => 'SavedQuote{text: $text, savedAt: $savedAt}';

  Map<String, dynamic> toJson() {
    return {'text': text, 'savedAt': savedAt.toIso8601String()};
  }

  factory SavedQuote.fromJson(Map<String, dynamic> json) {
    return SavedQuote(
      text: json['text'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

class SavedImage {
  final String url;
  final Map<String, String>? headers;
  final DateTime savedAt;

  const SavedImage({required this.url, this.headers, required this.savedAt});

  @override
  bool operator ==(Object other) =>
      other is SavedImage &&
      url == other.url &&
      savedAt == other.savedAt;

  @override
  int get hashCode => Object.hash(url, savedAt);

  @override
  String toString() =>
      'SavedImage{url: $url, headers: $headers, savedAt: $savedAt}';

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      if (headers != null) 'headers': headers,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedImage.fromJson(Map<String, dynamic> json) {
    return SavedImage(
      url: json['url'] as String,
      headers: (json['headers'] as Map<String, dynamic>?)?.cast(),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

class EpisodeData {
  bool bookmark;
  bool finished;
  String? progress;
  List<SavedQuote> quotes;
  List<SavedImage> images;
  EpisodeData({
    required this.bookmark,
    required this.finished,
    this.progress,
    List<SavedQuote>? quotes,
    List<SavedImage>? images,
  }) : quotes = quotes ?? [],
       images = images ?? [];
  EpisodeData.empty()
    : this(bookmark: false, finished: false, progress: null);

  @override
  bool operator ==(Object other) =>
      other is EpisodeData &&
      bookmark == other.bookmark &&
      finished == other.finished &&
      progress == other.progress &&
      _listEquals(quotes, other.quotes) &&
      _listEquals(images, other.images);

  @override
  int get hashCode =>
      Object.hash(bookmark, finished, progress, Object.hashAll(quotes),
          Object.hashAll(images));

  @override
  String toString() {
    return 'EpisodeData{bookmark: $bookmark, finished: $finished, '
        'progress: $progress, quotes: $quotes, images: $images}';
  }

  Map<String, dynamic> toJson() {
    return {
      'bookmark': bookmark,
      'finished': finished,
      'progress': progress,
      'quotes': quotes.map((e) => e.toJson()).toList(),
      'images': images.map((e) => e.toJson()).toList(),
    };
  }

  factory EpisodeData.fromJson(Map<String, dynamic> json) {
    return EpisodeData(
      bookmark: json['bookmark'] as bool,
      finished: json['finished'] as bool,
      progress: json['progress'] as String?,
      quotes:
          (json['quotes'] as List<dynamic>?)
              ?.map((e) => SavedQuote.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => SavedImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

class EntryExtension {
  final String extensionId;
  Map<String, rust.Setting> extensionSettings;

  CustomUI? ui;

  List<Map<String, dynamic>>? patch;
  int? patchGeneration;

  EntryExtension({
    required this.extensionId,
    required this.extensionSettings,
    this.ui,
    this.patch,
    this.patchGeneration,
  });

  factory EntryExtension.fromJson(Map<String, dynamic> json) {
    return EntryExtension(
      extensionId: json['extensionId'] as String,
      extensionSettings: (json['settings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, rust.JsonSetting.fromJson(value)),
      ),
      ui: json['ui'] == null ? null : JsonCustomUI.fromJson(json['ui']),
      patch: (json['patch'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      patchGeneration: json['patchGeneration'] as int?,
    );
  }

  Extension? get extension =>
      locate<ExtensionService>().tryGetExtension(extensionId);

  Map<String, dynamic> toJson() {
    return {
      'extensionId': extensionId,
      'settings': extensionSettings.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'ui': ui?.toJson(),
      if (patch != null)
        'patch': patch!.map((op) => Map<String, dynamic>.from(op)).toList(),
      if (patchGeneration != null) 'patchGeneration': patchGeneration,
    };
  }
}

class EntrySaved
    with DBConstClass, DBModifiableClass, DBLiveClass
    implements EntryDetailed {
  @override
  String boundExtensionId;

  rust.EntryDetailed original;

  rust.EntryDetailed entry;

  int generation;

  List<Category> categories;
  @override
  Map<String, rust.Setting> extensionSettings;
  EntrySavedSettings savedSettings;

  List<EpisodeData> _episodedata;
  int episode;

  List<EntryExtension> entryExtensions;
  List<EntryExtension> sourceExtensions;

  DateTime? lastRefreshed;

  DateTime? predictedNextRelease;

  Duration? releaseInterval;

  DateTime? nextReleaseOverride;

  DateTime? get nextRelease => nextReleaseOverride ?? predictedNextRelease;

  @override
  rust.EntryDetailed get toRust => entry;

  EntrySaved({
    required this.entry,
    required this.original,
    this.generation = 0,
    required this.categories,
    required List<EpisodeData> episodedata,
    required this.boundExtensionId,
    required this.episode,
    required this.savedSettings,
    required this.extensionSettings,
    this.entryExtensions = const [],
    this.sourceExtensions = const [],
    this.lastRefreshed,
    this.predictedNextRelease,
    this.releaseInterval,
    this.nextReleaseOverride,
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
  Link? get poster => entry.poster;
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
  CustomUI? get ui => original.ui;
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
      locate<ExtensionService>().tryGetExtension(boundExtensionId);

  @override
  FutureOr<EntryDetailed> toDetailed({rust.CancelToken? token}) {
    return EntryDetailed.fromSaved(this);
  }

  @override
  FutureOr<EntrySaved> toSaved({bool applyRules = true}) {
    return this;
  }

  @override
  Future<EntrySaved> toSavedWithCategories(
    List<Category> categories, {
    bool applyRules = true,
  }) async {
    // Already saved: rule application only happens on the initial save.
    this.categories = categories;
    await save();
    return this;
  }

  @override
  FutureOr<EntryDetailed> refresh({CancelToken? token}) async {
    final previousReleased = releasedEpisodes;
    await locate<ExtensionService>().detail(this, token: token);
    lastRefreshed = DateTime.now();
    updateReleasePrediction();
    if (releasedEpisodes > previousReleased) {
      // The awaited release arrived; a user-set date no longer applies.
      nextReleaseOverride = null;
    }
    await save();
    return this;
  }

  void updateReleasePrediction() {
    final prediction = predictNextRelease(
      entry.episodes.map((e) => e.timestamp),
    );
    predictedNextRelease = prediction?.nextRelease;
    // A pre-announced next release carries no interval; keep the last
    // cadence estimate instead of discarding it.
    if (prediction != null && prediction.interval > Duration.zero) {
      releaseInterval = prediction.interval;
    }
  }

  Future<void> save() async {
    await locate<Database>().updateEntry(this);
  }

  Future<void> delete() async {
    await locate<Database>().removeEntry(this);
  }

  @override
  void onDBChange(DBChange change) {
    unawaited(_onDBChange(change));
  }

  Future<void> _onDBChange(DBChange change) async {
    try {
      if (change.deleted) {
        locate<Database>().notifyListeners([DBEvent.entryAddedOrRemoved]);
        return;
      }
      final json = await _rowWithPatch(change.patch);
      final fresh = await EntrySaved.fromJson(json);
      boundExtensionId = fresh.boundExtensionId;
      entry = fresh.entry;
      original = fresh.original;
      generation = fresh.generation;
      categories = fresh.categories;
      extensionSettings = fresh.extensionSettings;
      savedSettings = fresh.savedSettings;
      _episodedata = fresh._episodedata;
      episode = fresh.episode;
      entryExtensions = fresh.entryExtensions;
      sourceExtensions = fresh.sourceExtensions;
      lastRefreshed = fresh.lastRefreshed;
      predictedNextRelease = fresh.predictedNextRelease;
      releaseInterval = fresh.releaseInterval;
      nextReleaseOverride = fresh.nextReleaseOverride;
      locate<Database>().notifyListeners([DBEvent.entryUpdated]);
    } catch (e, stack) {
      logger.e(
        'Failed to apply live database change to $dbId',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<Map<String, dynamic>> _rowWithPatch(
    List<Map<String, dynamic>> patch,
  ) async {
    final json = await toDBJson();
    // The patch addresses the full row; toJson omits the id.
    json['id'] = dbId;
    try {
      applyJsonPatch(json, patch);
    } catch (e) {
      logger.w(
        'Patch failed for live change on $dbId, re-reading row',
        error: e,
      );
      final row = await locate<Database>().db.select(dbId);
      if (row is! Map) {
        throw StateError('Row $dbId vanished during live change: $row');
      }
      return Map<String, dynamic>.from(row);
    }
    return json;
  }

  Future<void> onEntryActivity(
    int episodeNumber, {
    rust.CancelToken? token,
  }) async {
    for (final ext in entryExtensions) {
      await ext.extension?.onEntryActivity(
        EntryActivity.episodeActivity(progress: episodeNumber),
        this,
        ext.extensionSettings,
        token: token,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'version': entrySerializeVersion.current,
      'entry': entry.toJson(),
      'original': original.toJson(),
      'generation': generation,
      'extensionid': boundExtensionId,
      'episodedata': episodedata,
      'episode': episode,
      'categories': categories.map((e) => e.id).toList(),
      'entryExtensions': entryExtensions.map((e) => e.toJson()).toList(),
      'sourceExtensions': sourceExtensions.map((e) => e.toJson()).toList(),
      'savedSettings': savedSettings.toJson(),
      'lastRefreshed': lastRefreshed?.toIso8601String(),
      'predictedNextRelease': predictedNextRelease?.toIso8601String(),
      'releaseInterval': releaseInterval?.inMilliseconds,
      'nextReleaseOverride': nextReleaseOverride?.toIso8601String(),
      'extensionSettings': extensionSettings.map((key, value) {
        return MapEntry(key, value.toJson());
      }),
    };
  }

  static Future<List<Category>> handleCategories(dynamic categoryData) async {
    if (categoryData == null) return [];
    if (categoryData is! List) return [];
    if (categoryData.isEmpty) return [];
    if (categoryData[0] is Category) {
      return categoryData.cast<Category>();
    }
    if (categoryData[0] is Map<String, dynamic>) {
      return categoryData
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (categoryData[0] is DBRecord) {
      final db = locate<Database>();
      return await db.getCategoriesbyId(fromDynamic(categoryData).toList());
    }
    return [];
  }

  static Future<EntrySaved> fromJson(Map<String, dynamic> json) async {
    switch (json['version']) {
      case 1:
        final entry = rust.EntryDetailed(
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
        );
        return EntrySaved(
          entry: entry,
          // No separate source entry existed back then; the folded entry is
          // the best available refresh input until the next refresh.
          original: entry,
          categories: await handleCategories(json['categories']),
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
    final entry = rust.JsonEntryDetailed.fromJson(
      json['entry'] as Map<String, dynamic>,
    );
    return EntrySaved(
      entry: entry,
      // Rows written before the original/final split only stored the folded
      // entry; it doubles as the original until the next refresh.
      original:
          json['original'] == null
          ? entry
          : rust.JsonEntryDetailed.fromJson(
              json['original'] as Map<String, dynamic>,
            ),
      generation: (json['generation'] as int?) ?? 0,
      categories: await handleCategories(json['categories']),
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
      sourceExtensions:
          (json['sourceExtensions'] as List<dynamic>?)
              ?.map((e) => EntryExtension.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      entryExtensions:
          (json['entryExtensions'] as List<dynamic>?)
              ?.map((e) => EntryExtension.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastRefreshed: DateTime.tryParse(json['lastRefreshed'] as String? ?? ''),
      predictedNextRelease: DateTime.tryParse(
        json['predictedNextRelease'] as String? ?? '',
      ),
      releaseInterval:
          json['releaseInterval'] == null
              ? null
              : Duration(milliseconds: json['releaseInterval'] as int),
      nextReleaseOverride: DateTime.tryParse(
        json['nextReleaseOverride'] as String? ?? '',
      ),
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
  DBRecord get dbId => constructEntryDBRecord(id, boundExtensionId);

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    return toJson();
  }
}

DBRecord constructEntryDBRecord(EntryId id, String extensionId) =>
    DBRecord('entry', base64.encode(utf8.encode('${id.uid}_$extensionId')));

Iterable<DBRecord> fromDynamic(Iterable<dynamic> list) {
  return list.map(
    (e) => e is DBRecord ? e : DBRecord.fromJson(e as Map<String, dynamic>),
  );
}
