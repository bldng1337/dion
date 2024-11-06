import 'package:dionysos/service/source_extension.dart';
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

extension Ext on Entry {
  bool get inLibrary => false; //TODO Library detection

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'mediaType': mediaType.toString(),
        'cover': cover,
        'coverHeader': coverHeader,
        'author': author,
        'rating': rating,
        'views': views,
        'length': length,
      };
}

extension ReleaseStatus on rust.ReleaseStatus {
  String asString() => switch (this) {
        rust.ReleaseStatus.releasing => 'Releasing',
        rust.ReleaseStatus.complete => 'Complete',
        rust.ReleaseStatus.unknown => 'Unknown',
      };
}

extension ExtDetail on EntryDetailed {
  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'mediaType': mediaType.toString(),
        'cover': cover,
        'coverHeader': coverHeader,
        'author': author,
        'rating': rating,
        'views': views,
        'length': length,
        'description': description,
      };
}

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
}

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
  List<String>? get author => _entry.auther;

  @override
  double? get rating => _entry.rating;

  @override
  double? get views => _entry.views;

  @override
  int? get length => _entry.length;

  @override
  int get hashCode => _entry.hashCode;

  @override
  bool operator ==(Object other) => _entry == other;
}

class EpisodePath {
  final EntryDetailed entry;
  final int episodelist;
  final int episodenumber;
  const EpisodePath(this.entry, this.episodelist, this.episodenumber);
  EpisodeList get eplist => entry.episodes[episodelist];
  Episode get ep => eplist.episodes[episodenumber];
}

abstract class EntryDetailed extends Entry {
  String get ui;
  rust.ReleaseStatus get status;
  String get description;
  String get language;
  List<rust.EpisodeList> get episodes;
  List<String>? get genres;
  List<String>? get alttitles;
  List<String>? get auther;
}

class EntryDetailedImpl implements EntryDetailed {
  final rust.EntryDetailed _entry;
  final Extension _extension;
  EntryDetailedImpl(this._entry, this._extension);

  @override
  Extension get extension => _extension;

  @override
  String get id => _entry.id;

  @override
  String get url => _entry.url;

  @override
  String get title => _entry.title;

  @override
  MediaType get mediaType => _entry.mediaType;

  @override
  String? get cover => _entry.cover;

  @override
  Map<String, String>? get coverHeader => _entry.coverHeader;

  @override
  List<String>? get author => _entry.auther;

  @override
  double? get rating => _entry.rating;

  @override
  double? get views => _entry.views;

  @override
  int? get length => _entry.length;

  @override
  String get ui => _entry.ui;

  @override
  rust.ReleaseStatus get status => _entry.status;

  @override
  String get description => _entry.description;

  @override
  String get language => _entry.language;

  @override
  List<rust.EpisodeList> get episodes => _entry.episodes;

  @override
  List<String>? get genres => _entry.genres;

  @override
  List<String>? get alttitles => _entry.alttitles;

  @override
  List<String>? get auther => _entry.auther;
}
