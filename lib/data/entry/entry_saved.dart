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
import 'package:dionysos/utils/log.dart';
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
  EntryExtension({required this.extensionId, required this.extensionSettings, this.ui});

  factory EntryExtension.fromJson(Map<String, dynamic> json) {
    return EntryExtension(
      extensionId: json['extensionId'] as String,
      extensionSettings: (json['settings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, rust.JsonSetting.fromJson(value)),
      ),
      ui: json['ui'] == null ? null : JsonCustomUI.fromJson(json['ui']),
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
    };
  }
}

class EntrySaved
    with DBConstClass, DBModifiableClass, DBLiveClass
    implements EntryDetailed {
  @override
  String boundExtensionId;
  rust.EntryDetailed entry;

  List<Category> categories;
  @override
  Map<String, rust.Setting> extensionSettings;
  EntrySavedSettings savedSettings;

  List<EpisodeData> _episodedata;
  int episode;

  List<EntryExtension> entryExtensions;
  List<EntryExtension> sourceExtensions;

  @override
  rust.EntryDetailed get toRust => entry;

  EntrySaved({
    required this.entry,
    required this.categories,
    required List<EpisodeData> episodedata,
    required this.boundExtensionId,
    required this.episode,
    required this.savedSettings,
    required this.extensionSettings,
    this.entryExtensions = const [],
    this.sourceExtensions = const [],
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
      locate<ExtensionService>().tryGetExtension(boundExtensionId);

  @override
  FutureOr<EntryDetailed> toDetailed({rust.CancelToken? token}) {
    return EntryDetailed.fromSaved(this);
  }

  @override
  FutureOr<EntrySaved> toSaved() {
    return this;
  }

  @override
  Future<EntrySaved> toSavedWithCategories(List<Category> categories) async {
    this.categories = categories;
    await save();
    return this;
  }

  @override
  FutureOr<EntryDetailed> refresh({CancelToken? token}) async {
    await locate<ExtensionService>().detail(this, token: token);
    await save();
    return this;
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
      categories = fresh.categories;
      extensionSettings = fresh.extensionSettings;
      savedSettings = fresh.savedSettings;
      _episodedata = fresh._episodedata;
      episode = fresh.episode;
      entryExtensions = fresh.entryExtensions;
      sourceExtensions = fresh.sourceExtensions;
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
      _applyJsonPatch(json, patch);
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
      'extensionid': boundExtensionId,
      'episodedata': episodedata,
      'episode': episode,
      'categories': categories.map((e) => e.id).toList(),
      'entryExtensions': entryExtensions.map((e) => e.toJson()).toList(),
      'sourceExtensions': sourceExtensions.map((e) => e.toJson()).toList(),
      'savedSettings': savedSettings.toJson(),
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
    return EntrySaved(
      entry: rust.JsonEntryDetailed.fromJson(
        json['entry'] as Map<String, dynamic>,
      ),
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

void _applyJsonPatch(Map<String, dynamic> doc, List<Map<String, dynamic>> ops) {
  for (final op in ops) {
    final path = op['path'];
    if (path is! String) {
      throw StateError('Patch op without a path: $op');
    }
    final tokens = _jsonPointerTokens(path);
    if (tokens.isEmpty) {
      throw StateError('Unsupported root patch path: $path');
    }
    final parent = _resolvePointer(doc, tokens.sublist(0, tokens.length - 1));
    final key = tokens.last;
    final value = op['value'];
    switch (op['op']) {
      case 'add' || 'replace':
        if (parent is List) {
          final index = key == '-' ? parent.length : int.parse(key);
          if (index > parent.length) {
            throw StateError('Patch index $index out of bounds: $path');
          }
          if (op['op'] == 'add' && index == parent.length) {
            parent.add(value);
          } else {
            parent[index] = value;
          }
        } else if (parent is Map) {
          parent[key] = value;
        } else {
          throw StateError('Cannot patch into ${parent.runtimeType}: $path');
        }
      case 'remove':
        if (parent is List) {
          parent.removeAt(int.parse(key));
        } else if (parent is Map) {
          parent.remove(key);
        } else {
          throw StateError('Cannot patch into ${parent.runtimeType}: $path');
        }
      default:
        throw StateError('Unsupported patch op: ${op['op']}');
    }
  }
}

List<String> _jsonPointerTokens(String pointer) => pointer
    .split('/')
    .skip(1)
    .map((t) => t.replaceAll('~1', '/').replaceAll('~0', '~'))
    .toList();

dynamic _resolvePointer(dynamic doc, List<String> tokens) {
  var current = doc;
  for (final token in tokens) {
    if (current is List) {
      current = current[int.parse(token)];
    } else if (current is Map) {
      final next = current[token];
      if (next == null) {
        throw StateError('Patch path leads through missing key "$token"');
      }
      current = next;
    } else {
      throw StateError('Cannot descend into ${current.runtimeType}');
    }
  }
  return current;
}
