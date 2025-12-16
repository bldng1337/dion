import 'dart:async';

import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
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

  FutureOr<EntrySaved> toSaved();
  FutureOr<EntryDetailed> refresh({CancelToken? token});
}

class EntryDetailedImpl implements EntryDetailed {
  @override
  final Map<String, rust.Setting> extensionSettings;
  final rust.EntryDetailed entry;
  @override
  final String boundExtensionId;

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
      locate<SourceExtension>().tryGetExtension(boundExtensionId);

  @override
  Future<EntryDetailed> refresh({CancelToken? token}) {
    return locate<SourceExtension>().detail(this, token: token);
  }

  @override
  EntryDetailed toDetailed({CancelToken? token}) {
    return this;
  }

  @override
  Future<EntrySaved> toSaved() async {
    final saved = EntrySaved(
      entry: entry,
      categories: [],
      episodedata: [],
      boundExtensionId: boundExtensionId,
      episode: 0,
      savedSettings: EntrySavedSettings.defaultSettings(),
      extensionSettings: extensionSettings,
    );
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
  DBRecord get dbId => constructEntryDBRecord(this);

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
