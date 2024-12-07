import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  bool get inLibrary => this is EntrySaved; //TODO Library detection
}

extension ReleaseStatus on rust.ReleaseStatus {
  String asString() => switch (this) {
        rust.ReleaseStatus.releasing => 'Releasing',
        rust.ReleaseStatus.complete => 'Complete',
        rust.ReleaseStatus.unknown => 'Unknown',
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
  Future<EntryDetailed> toDetailed({CancelToken? token});
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
}

abstract class EntryDetailed extends Entry {
  CustomUi? get ui;
  rust.ReleaseStatus get status;
  String get description;
  String get language;
  List<rust.EpisodeList> get episodes;
  List<String>? get genres;
  List<String>? get alttitles;
  List<String>? get auther;
  Future<EntrySaved> toSaved();
  Future<EntryDetailed> refresh({CancelToken? token});
}

abstract class EntrySaved extends EntryDetailed {
  Future<EntrySaved> save();
  Future<EntryDetailed> delete();
  List<EpisodeData> get episodedata;
  int get episode;
  set episode(int value);
  EpisodeData getEpisodeData(int episode);

  set _episodedata(List<EpisodeData> value);
  List<EpisodeData> get _episodedata;

  int get latestEpisode;
  int get totalEpisodes;

  @override
  Future<EntrySaved> toSaved() {
    return Future.value(this);
  }
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
}

class EpisodePath {
  final EntryDetailed entry;
  final int episodelist;
  final int episodenumber;
  const EpisodePath(this.entry, this.episodelist, this.episodenumber);

  EpisodeData get data => (entry is EntrySaved)
      ? (entry as EntrySaved).getEpisodeData(episodenumber)
      : EpisodeData.empty();

  EpisodeList get eplist => entry.episodes[episodelist];
  Episode get episode => eplist.episodes[episodenumber];
  String get name => episode.name;
  bool get hasnext => episodenumber + 1 < eplist.episodes.length;
  bool get hasprev => episodenumber > 0;
  void goPrev(BuildContext context) {
    if (!hasprev) return;
    GoRouter.of(context).pushReplacement(
      '/view',
      extra: [prev],
    );
  }

  Future<void> save() =>
      entry is EntrySaved ? (entry as EntrySaved).save() : Future.value();

  Future<void> goNext(BuildContext context) async {
    if (!hasnext) return;
    data.finished = true;
    await save();
    if (context.mounted) {
      await GoRouter.of(context).pushReplacement(
        '/view',
        extra: [next],
      );
    }
  }

  void go(BuildContext context) {
    GoRouter.of(context).push(
      '/view',
      extra: [this],
    );
  }

  EpisodePath get next => EpisodePath(entry, episodelist, episodenumber + 1);
  EpisodePath get prev => EpisodePath(entry, episodelist, episodenumber - 1);
  Extension get extension => entry.extension;

  @override
  String toString() {
    return 'EpisodePath(entry: $entry, episodelist: $episodelist, episodenumber: $episodenumber)';
  }

  @override
  bool operator ==(Object other) {
    return other is EpisodePath &&
        other.entry == entry &&
        other.episodelist == episodelist &&
        other.episodenumber == episodenumber;
  }

  @override
  int get hashCode => Object.hash(entry, episodelist, episodenumber);
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
  List<String>? get author => _entry.author;

  @override
  double? get rating => _entry.rating;

  @override
  double? get views => _entry.views;

  @override
  int? get length => _entry.length;

  @override
  CustomUi? get ui => _entry.ui;

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
  List<String>? get auther => _entry.author;

  @override
  Future<EntryDetailed> refresh({CancelToken? token}) {
    return locate<SourceExtension>().detail(this, token: token);
  }

  @override
  Future<EntryDetailed> toDetailed({CancelToken? token}) {
    return refresh(token: token);
  }

  @override
  Future<EntrySaved> toSaved() async {
    final saved = EntrySavedImpl(_entry, extension, List.empty());
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
}

class EntrySavedImpl extends EntryDetailedImpl implements EntrySaved {
  @override
  List<EpisodeData> _episodedata;
  EntrySavedImpl(super.entry, super.extension, this._episodedata);

  @override
  List<EpisodeData> get episodedata => _episodedata;

  @override
  int episode = 0;
  @override
  Future<EntrySaved> refresh({CancelToken? token}) async {
    final ent = await locate<SourceExtension>().update(this, token: token);
    ent.episode = episode;
    ent._episodedata = episodedata;
    await ent.save();
    return ent;
  }

  EntrySaved copywith(rust.EntryDetailed ent) {
    return EntrySavedImpl(ent, extension, _episodedata);
  }

  @override
  Future<EntryDetailed> delete() async {
    await locate<Database>().removeEntry(this);
    return EntryDetailedImpl(_entry, _extension);
  }

  @override
  int get latestEpisode =>
      episodedata.lastIndexWhere((e) => e.finished == true) + 1;

  @override
  int get totalEpisodes => episodes[episode].episodes.length;

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
}
