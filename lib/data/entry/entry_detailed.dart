import 'dart:async';

import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

abstract class EntryDetailed extends Entry {
  CustomUI? get ui;
  ReleaseStatus get status;
  String get description;
  String get language;
  List<Episode> get episodes;
  List<String>? get genres;
  List<String>? get alttitles;

  FutureOr<EntrySaved> toSaved();
  FutureOr<EntryDetailed> refresh({CancelToken? token});
}

class EntryDetailedImpl implements EntryDetailed {
  final rust.EntryDetailed entry;
  @override
  final Extension extension;

  const EntryDetailedImpl(this.entry, this.extension);

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
  Future<EntryDetailed> refresh({CancelToken? token}) {
    return locate<SourceExtension>().detail(this, token: token);
  }

  @override
  EntryDetailed toDetailed({CancelToken? token}) {
    return this;
  }

  @override
  Future<EntrySaved> toSaved() async {
    final saved = EntrySaved.fromEntryDetailed(this);
    await saved.save();
    return saved;
  }

  @override
  bool operator ==(Object other) =>
      other is EntryDetailedImpl &&
      other.entry == entry &&
      other.extension == extension;

  @override
  int get hashCode => Object.hashAll([entry, extension]);

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
}
