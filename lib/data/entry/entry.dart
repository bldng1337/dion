import 'dart:async';

import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/versioning.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/metis.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

abstract class Entry {
  Extension get extension;
  String get id;
  String get url;
  String get title;
  MediaType get mediaType;
  String? get cover;
  Map<String, String>? get coverHeader;
  List<String>? get author;
  double? get rating;
  double? get views;
  int? get length;
  FutureOr<EntryDetailed> toDetailed({CancelToken? token});
  DBRecord get dbId;
  Map<String, dynamic> toEntryJson();

  static Entry fromJson(Map<String, dynamic> json) {
    final exts = locate<SourceExtension>();
    return EntryImpl(
      rust.Entry.fromJson(json['entry'] as Map<String, dynamic>),
      exts.getExtension(json['extensionid'] as String),
    );
  }
}

class EntryImpl implements Entry {
  final rust.Entry _entry;
  @override
  final Extension extension;
  EntryImpl(this._entry, this.extension);

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
  int get hashCode => _entry.hashCode ^ extension.hashCode;
  @override
  bool operator ==(Object other) =>
      other is EntryImpl &&
      other._entry == _entry &&
      other.extension == extension;

  @override
  String toString() {
    return 'EntryImpl{_entry: $_entry, _extension: $extension}';
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
      'entry': _entry.toJson(),
      'extensionid': extension.id,
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
