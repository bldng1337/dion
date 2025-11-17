import 'dart:async';

import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

abstract class Entry {
  EntryId get id;
  String get boundExtensionId;
  String get url;
  String get title;
  MediaType get mediaType;
  Link? get cover;
  List<String>? get author;
  double? get rating;
  double? get views;
  int? get length;
  FutureOr<EntryDetailed> toDetailed({CancelToken? token});
  DBRecord get dbId;
  Map<String, dynamic> toEntryJson();

  Extension? get extension;

  static Entry fromJson(Map<String, dynamic> json) {
    switch (json['version']) {
      case 1:
        print("Upgrade entry from version 1 to 2");
        return EntryImpl(
          rust.Entry(
            id: EntryId(uid: json['entry']['id'] as String),
            mediaType: JsonMediaType.fromJson(
              json['entry']['mediaType'] as String,
            ),
            url: json['entry']['url'] as String,
            title: json['entry']['title'] as String,
            cover: Link(
              url: json['entry']['cover'] as String,
              header: (json['entry']['coverHeader'] as Map<String, dynamic>?)
                  ?.cast(),
            ),
            author: (json['entry']['author'] as List<dynamic>?)?.cast(),
            rating: json['entry']['rating'] as double?,
            views: json['entry']['views'] as double?,
            length: json['entry']['length'] as int?,
          ),
          json['extensionid'] as String,
        );
    }
    if (json['version'] != entrySerializeVersion.current) {
      throw Exception('Unsupported entry version ${json['version']}');
    }
    return EntryImpl(
      rust.JsonEntry.fromJson(json['entry'] as Map<String, dynamic>),
      json['boundExtensionId'] as String,
    );
  }
}

class EntryImpl implements Entry {
  final rust.Entry _entry;
  @override
  final String boundExtensionId;
  const EntryImpl(this._entry, this.boundExtensionId);

  @override
  EntryId get id => _entry.id;
  @override
  String get url => _entry.url;
  @override
  String get title => _entry.title;
  @override
  rust.MediaType get mediaType => _entry.mediaType;
  @override
  Link? get cover => _entry.cover;
  @override
  List<String>? get author => _entry.author;
  @override
  double? get rating => _entry.rating;
  @override
  double? get views => _entry.views;
  @override
  int? get length => _entry.length;
  @override
  Extension? get extension =>
      locate<SourceExtension>().tryGetExtension(boundExtensionId);

  @override
  int get hashCode => _entry.hashCode;
  @override
  bool operator ==(Object other) =>
      other is EntryImpl && other._entry == _entry;

  @override
  String toString() {
    return 'EntryImpl{_entry: $_entry}';
  }

  @override
  Future<EntryDetailed> toDetailed({CancelToken? token}) async {
    return await locate<SourceExtension>().detail(this, token: token);
  }

  @override
  DBRecord get dbId => constructEntryDBRecord(this);

  @override
  Map<String, dynamic> toEntryJson() {
    return {
      'version': entrySerializeVersion.current,
      'type': 'entry',
      'boundExtensionId': boundExtensionId,
      'entry': _entry.toJson(),
    };
  }
}

extension ReleaseStatusExt on ReleaseStatus {
  String asString() => switch (this) {
    ReleaseStatus.complete => 'Complete',
    ReleaseStatus.releasing => 'Releasing',
    ReleaseStatus.unknown => 'Unknown',
  };
}
