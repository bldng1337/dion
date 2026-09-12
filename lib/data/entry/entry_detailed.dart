import 'dart:async';

import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/autoadd.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

abstract class EntryDetailed extends Entry {
  Map<String, rust.Setting> get extensionSettings;
  CustomUI? get ui;
  ReleaseStatus get status;
  String get description;
  List<String>? get titles;
  String get language;
  List<Episode> get episodes;
  List<String>? get genres;
  Link? get poster;

  rust.EntryDetailed get toRust;

  FutureOr<EntrySaved> toSaved({bool applyRules = true});
  Future<EntrySaved> toSavedWithCategories(
    List<Category> categories, {
    bool applyRules = true,
  });
  FutureOr<EntryDetailed> refresh({CancelToken? token});

  static EntryDetailed fromSaved(EntrySaved saved) {
    return EntryDetailedImpl(
      saved.entry,
      saved.boundExtensionId,
      saved.extensionSettings,
    );
  }
}

extension EntryDetailedReleaseInfo on EntryDetailed {
  int get releasedEpisodes =>
      episodes.where((e) => e.announced != true).length;
}

class EntryDetailedImpl implements EntryDetailed {
  @override
  final Map<String, rust.Setting> extensionSettings;
  final rust.EntryDetailed entry;
  @override
  final String boundExtensionId;

  @override
  rust.EntryDetailed get toRust => entry;

  const EntryDetailedImpl(
    this.entry,
    this.boundExtensionId,
    this.extensionSettings,
  );

  @override
  EntryId get id => entry.id;
  @override
  Link? get poster => entry.poster;
  @override
  String get url => entry.url;
  @override
  String get title => entry.titles.first;
  @override
  List<String> get titles => entry.titles;
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
  Future<EntryDetailed> refresh({CancelToken? token}) {
    return locate<ExtensionService>().detail(this, token: token);
  }

  @override
  EntryDetailed toDetailed({CancelToken? token}) {
    return this;
  }

  @override
  Future<EntrySaved> toSaved({bool applyRules = true}) async {
    final saved = EntrySaved(
      entry: entry,
      original: entry,
      categories: [],
      episodedata: [],
      boundExtensionId: boundExtensionId,
      episode: 0,
      savedSettings: EntrySavedSettings.defaultSettings(),
      extensionSettings: extensionSettings,
    );
    saved.updateReleasePrediction();
    if (applyRules) {
      await attachAutoAddExtensions(saved);
    }
    await locate<Database>().addEntry(saved);
    return saved;
  }

  @override
  Future<EntrySaved> toSavedWithCategories(
    List<Category> categories, {
    bool applyRules = true,
  }) async {
    final saved = EntrySaved(
      entry: entry,
      original: entry,
      categories: categories,
      episodedata: [],
      boundExtensionId: boundExtensionId,
      episode: 0,
      savedSettings: EntrySavedSettings.defaultSettings(),
      extensionSettings: extensionSettings,
    );
    saved.updateReleasePrediction();
    if (applyRules) {
      await attachAutoAddExtensions(saved);
    }
    await locate<Database>().addEntry(saved);
    return saved;
  }

  @override
  bool operator ==(Object other) =>
      other is EntryDetailedImpl &&
      other.entry == entry &&
      other.boundExtensionId == boundExtensionId;

  @override
  int get hashCode => Object.hashAll([entry, boundExtensionId]);

  @override
  DBRecord get dbId => constructEntryDBRecord(id, boundExtensionId);

  /// Makes instances JSON-encodable: go_router reports the pushed `extra`
  /// (e.g. `['/detail', extra: [this]]`) through a JSON method channel.
  /// The content is never decoded back.
  Map<String, dynamic> toJson() => toEntryJson();

  @override
  Map<String, dynamic> toEntryJson() {
    return {
      'version': entrySerializeVersion.current,
      'type': 'entry',
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
      'boundExtensionId': boundExtensionId,
    };
  }
}
