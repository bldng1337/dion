import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/extension_setting.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart' as appsettings;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

extension EntryX on rust.Entry {
  Entry wrap(Extension e) {
    return EntryImpl(this, e);
  }
}

extension EntryDetailedX on rust.EntryDetailed {
  EntryDetailed wrap(Extension e) {
    return EntryDetailedImpl(this, e);
  }
}

extension ReleaseStatus on rust.ReleaseStatus {
  String asString() => switch (this) {
        rust.ReleaseStatus.releasing => 'Releasing',
        rust.ReleaseStatus.complete => 'Complete',
        rust.ReleaseStatus.unknown => 'Unknown',
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
    return {
      'bookmark': bookmark,
      'finished': finished,
      'progress': progress,
    };
  }

  factory EpisodeData.fromJson(Map<String, dynamic> json) {
    return EpisodeData(
      bookmark: json['bookmark'] as bool,
      finished: json['finished'] as bool,
      progress: json['progress'] as String?,
    );
  }
}

class EntrySettingMetaData<T> extends appsettings.SettingMetaData<T>
    implements ExtensionSettingMetaData<T> {
  final EntrySaved entry;
  final String settingkey;
  const EntrySettingMetaData(this.entry, this.settingkey);

  @override
  void onChange(T v) {
    final settingval = entry.rawsettings?[settingkey]?.val.updateWith(v);
    if (settingval == null) return;
    entry.setSetting(settingkey, settingval);
  }

  @override
  String get id => settingkey;

  @override
  rust.Setting get setting => entry.rawsettings![settingkey]!;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// INTERFACES
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
abstract class Entry {
  Extension get extension;
  String get id;
  String get url;
  String get title;
  rust.MediaType get mediaType;
  String? get cover;
  Map<String, String>? get coverHeader;
  List<String>? get author;
  double? get rating;
  double? get views;
  int? get length;
  Future<EntryDetailed> toDetailed({CancelToken? token});
  Map<String, dynamic> toJson();
  static Entry fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'entry':
        return EntryImpl.fromJson(json);
      default:
        return EntryImpl.fromJson(json);
    }
  }
}

abstract class EntryDetailed extends Entry {
  CustomUI? get ui;
  rust.ReleaseStatus get status;
  String get description;
  String get language;
  List<Episode> get episodes;
  List<String>? get genres;
  List<String>? get alttitles;
  List<String>? get auther;
  Map<String, rust.Setting>? get rawsettings;
  Future<EntrySaved> toSaved();
  Future<EntryDetailed> refresh({CancelToken? token});

  static Future<EntryDetailed> fromJson(Map<String, dynamic> json) async {
    switch (json['type']) {
      case 'entrydetailed':
        return EntryDetailedImpl.fromJson(json);
      case 'entrysaved':
        return EntrySaved.fromJson(json);
      default:
        return EntryDetailed.fromJson(json);
    }
  }
}

abstract class EntrySaved extends EntryDetailed {
  Future<EntrySaved> save();
  Future<EntryDetailed> delete();
  List<EpisodeData> get episodedata;
  List<Category> get categories;
  List<appsettings.Setting<dynamic, EntrySettingMetaData<dynamic>>>
      get settings;

  set categories(List<Category> value);
  int get episode;
  set episode(int value);
  EpisodeData getEpisodeData(int episode);
  void setSetting(String key, Settingvalue value);

  set _episodedata(List<EpisodeData> value);
  List<EpisodeData> get _episodedata;

  int get latestEpisode;
  int get totalEpisodes;

  @override
  Future<EntrySaved> toSaved() {
    return Future.value(this);
  }

  static Future<EntrySaved> fromJson(Map<String, dynamic> json) async {
    final db = locate<Database>();
    return EntrySavedImpl.fromJson(
      json,
      await db
          .getCategory((json['categories'] as List<dynamic>?)?.cast() ?? []),
    );
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// IMPLEMENTATIONS
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
class EntryImpl implements Entry {
  final rust.Entry _entry;
  final Extension _extension;
  EntryImpl(this._entry, this._extension);

  @override
  Extension get extension => _extension;

  @override
  String get id => _entry.id;

  @override
  String get url => _entry.url;

  @override
  String get title => _entry.title;

  @override
  rust.MediaType get mediaType => _entry.mediaType;

  @override
  String? get cover => _entry.cover;

  @override
  Map<String, String>? get coverHeader => _entry.coverHeader;

  @override
  List<String>? get author => _entry.author;

  @override
  double? get rating => _entry.rating;

  @override
  double? get views => _entry.views;

  @override
  int? get length => _entry.length;

  @override
  int get hashCode => _entry.hashCode ^ _extension.hashCode;

  @override
  bool operator ==(Object other) =>
      other is EntryImpl &&
      other._entry == _entry &&
      other._extension == _extension;

  @override
  String toString() {
    return 'EntryImpl{_entry: $_entry, _extension: $_extension}';
  }

  @override
  Future<EntryDetailed> toDetailed({CancelToken? token}) async {
    return await locate<SourceExtension>().detail(this, token: token);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'entry',
      'entry': _entry.toJson(),
      'extensionid': _extension.id,
    };
  }

  factory EntryImpl.fromJson(Map<String, dynamic> json) {
    return EntryImpl(
      rust.Entry.fromJson(json['entry'] as Map<String, dynamic>),
      locate<SourceExtension>().getExtension(json['extensionid'] as String),
    );
  }
}

class EntryDetailedImpl implements EntryDetailed {
  rust.EntryDetailed _entry;
  final Extension _extension;

  EntryDetailedImpl(this._entry, this._extension);

  @override
  Extension get extension => _extension;

  @override
  String get id => _entry.id;

  @override
  String get url => _entry.url;

  @override
  Map<String, rust.Setting>? get rawsettings => _entry.settings;

  @override
  String get title => _entry.title;

  @override
  MediaType get mediaType => _entry.mediaType;

  @override
  String? get cover => _entry.cover;

  @override
  Map<String, String>? get coverHeader => _entry.coverHeader;

  @override
  List<String>? get author => _entry.author;

  @override
  double? get rating => _entry.rating;

  @override
  double? get views => _entry.views;

  @override
  int? get length => _entry.length;

  @override
  CustomUI? get ui => _entry.ui;

  @override
  rust.ReleaseStatus get status => _entry.status;

  @override
  String get description => _entry.description;

  @override
  String get language => _entry.language;

  @override
  List<Episode> get episodes => _entry.episodes;

  @override
  List<String>? get genres => _entry.genres;

  @override
  List<String>? get alttitles => _entry.alttitles;

  @override
  List<String>? get auther => _entry.author;

  @override
  Future<EntryDetailed> refresh({CancelToken? token}) {
    return locate<SourceExtension>().detail(this, token: token);
  }

  @override
  Future<EntryDetailed> toDetailed({CancelToken? token}) async {
    return this;
  }

  @override
  Future<EntrySaved> toSaved() async {
    final saved = EntrySavedImpl.fromEntryDetailed(this);
    await saved.save();
    return saved;
  }

  @override
  bool operator ==(Object other) =>
      other is EntryDetailedImpl &&
      other._entry == _entry &&
      other._extension == _extension;

  @override
  int get hashCode => _entry.hashCode ^ _extension.hashCode;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'entrydetailed',
      'entry': _entry.toJson(),
      'extensionid': _extension.id,
    };
  }

  factory EntryDetailedImpl.fromJson(Map<String, dynamic> json) {
    final exts = locate<SourceExtension>();
    return EntryDetailedImpl(
      rust.EntryDetailed.fromJson(
        json['entry'] as Map<String, dynamic>,
      ),
      exts.getExtension(json['extensionid'] as String),
    );
  }
}

class EntrySavedImpl extends EntryDetailedImpl implements EntrySaved {
  @override
  List<EpisodeData> _episodedata;

  @override
  List<Category> categories;

  @override
  int episode;

  EntrySavedImpl(
    super.entry,
    super.extension,
    this._episodedata,
    this.episode,
    this.categories,
  );

  EntrySavedImpl.fromEntryDetailed(EntryDetailedImpl ent)
      : this(ent._entry, ent._extension, List.empty(), 0, List.empty());

  @override
  List<EpisodeData> get episodedata => _episodedata;

  @override
  List<appsettings.Setting<dynamic, EntrySettingMetaData<dynamic>>>
      get settings {
    if (rawsettings == null) return [];
    return rawsettings!.entries
        .map((e) => e.value.toSetting(EntrySettingMetaData(this, e.key)))
        .toList();
  }

  @override
  int get latestEpisode =>
      episodedata.lastIndexWhere((e) => e.finished == true) + 1;

  @override
  int get totalEpisodes => episodes.length;

  @override
  Future<EntrySaved> refresh({CancelToken? token}) async {
    final ent = await locate<SourceExtension>()
        .update(this, token: token, settings: rawsettings ?? {});
    ent.episode = episode;
    ent._episodedata = episodedata;
    await ent.save();
    return ent;
  }

  @override
  Future<EntryDetailed> delete() async {
    await locate<Database>().removeEntry(this);
    return EntryDetailedImpl(_entry, _extension);
  }

  @override
  Future<EntrySaved> save() async {
    await locate<Database>().updateEntry(this);
    return this;
  }

  @override
  EpisodeData getEpisodeData(int episode) {
    if (episodedata.length > episode) {
      return episodedata[episode];
    }
    final List<EpisodeData> data = List.generate(episode + 1, (index) {
      if (episodedata.length > index) {
        return episodedata[index];
      }
      return EpisodeData.empty();
    });
    _episodedata = data;
    return data[episode];
  }

  @override
  void setSetting(String key, Settingvalue value) {
    final newsettings = {
      ...rawsettings!,
      key: rawsettings![key]!.copyWith(val: value),
    };
    _entry = _entry.copyWith(settings: newsettings);
  }

  @override
  String toString() {
    return 'EntrySavedImpl{_entry: $_entry, _extension: $_extension, episodedata: $episodedata, episode: $episode}';
  }

  @override
  bool operator ==(Object other) =>
      other is EntrySavedImpl &&
      other._entry == _entry &&
      other._extension == _extension &&
      other.episodedata == episodedata &&
      other.episode == episode;

  @override
  int get hashCode =>
      _entry.hashCode ^
      _extension.hashCode ^
      episodedata.hashCode ^
      episode.hashCode;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'entrysaved',
      'entry': _entry.toJson(),
      'extensionid': _extension.id,
      'episodedata': episodedata,
      'episode': episode,
      'categories': categories.map((e) => e.id).toList(),
    };
  }

  factory EntrySavedImpl.fromJson(
    Map<String, dynamic> json,
    List<Category> categories,
  ) {
    final exts = locate<SourceExtension>();
    return EntrySavedImpl(
      rust.EntryDetailed.fromJson(json['entry'] as Map<String, dynamic>),
      exts.getExtension(json['extensionid'] as String),
      (json['episodedata'] as List<dynamic>?)
              ?.map((e) => EpisodeData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['episode'] as int?) ?? 0,
      categories,
    );
  }
}
