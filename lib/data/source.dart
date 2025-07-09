import 'dart:async';

import 'package:dionysos/data/activity.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cache.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';

class SourcePath {
  final EpisodePath episode;
  final Source source;
  const SourcePath(this.episode, this.source);
  String get name => episode.episode.name;
}

class EpisodePath {
  final EntryDetailed entry;
  final int episodenumber;
  const EpisodePath(this.entry, this.episodenumber);

  EpisodeData get data => (entry is EntrySaved)
      ? (entry as EntrySaved).getEpisodeData(episodenumber)
      : EpisodeData.empty();

  List<Episode> get episodes => entry.episodes;
  Episode get episode => episodes[episodenumber];
  bool get hasnext => episodenumber + 1 < episodes.length;
  bool get hasprev => episodenumber > 0;

  String get name => episode.name;
  String? get cover => episode.cover ?? entry.cover;
  Map<String, String>? get coverHeader =>
      episode.cover != null ? episode.coverHeader : entry.coverHeader;

  void goPrev(SourceSupplier supplier) {
    print("Going to prev");
    if (!hasprev) return;
    supplier.episode = prev;
  }

  Future<void> save() =>
      entry is EntrySaved ? (entry as EntrySaved).save() : Future.value();

  Future<void> goNext(SourceSupplier supplier) async {
    print("Going to next");
    if (!hasnext) return;
    data.finished = true;
    finishEpisode(this);
    await save();
    supplier.episode = next;
  }

  void go(BuildContext context) {
    finishEpisode(this);
    GoRouter.of(context).push(
      '/view',
      extra: [this],
    );
  }

  EpisodePath get next => EpisodePath(entry, episodenumber + 1);
  EpisodePath get prev => EpisodePath(entry, episodenumber - 1);
  Extension get extension => entry.extension;

  @override
  String toString() {
    return 'EpisodePath(entry: $entry, episodenumber: $episodenumber)';
  }

  @override
  bool operator ==(Object other) {
    return other is EpisodePath &&
        other.entry == entry &&
        other.episodenumber == episodenumber;
  }

  @override
  int get hashCode => Object.hash(entry, episodenumber);
}

class SourceSupplier with ChangeNotifier implements Disposable {
  SourcePath? _source;
  late StreamController<SourcePath> streamcontroller;
  late EpisodePath _episode;

  Object? _error;
  StackTrace? _stack;

  Completer<void>? _loading;
  CancelToken? tok;

  late DionMapCache<EpisodePath, SourcePath> cache;

  SourceSupplier(EpisodePath episode) {
    streamcontroller = StreamController<SourcePath>();
    cache = DionMapCache.fromsize(
      maximumSize: 5,
      loader: _loadSource,
    );
    _episode = episode;
    _getSource();
  }

  EpisodePath get episode => _episode;
  SourcePath? get source => _source;
  Stream<SourcePath> get sourcestream => streamcontroller.stream;

  bool get haserror => _error != null;
  Object? get error => _error;
  StackTrace? get stacktrace => _stack;

  bool get loading => !(_loading?.isCompleted ?? true);

  set episode(EpisodePath? value) {
    if (value == null) return;
    if (value == _episode) return;
    _episode = value;
    _source = null;
    _getSource();
    notifyListeners();
  }

  void preload(EpisodePath ep) {
    if (ep == _episode) return;
    cache.preload(ep);
  }

  void invalidate(EpisodePath ep) {
    cache.invalidate(ep);
    if (ep == _episode) {
      _source = null;
      _getSource();
    }
  }

  void invalidateCurrent() {
    invalidate(_episode);
  }

  Future<void> _getSource() async {
    if (loading) {
      await _loading!.future;
    }
    _loading = Completer<void>();
    notifyListeners();
    final res = await cache.get(_episode!);
    if (res.isSuccess) {
      _source = res.getOrThrow;
      streamcontroller.add(_source!);
    } else {
      _error = res.exceptionOrNull;
      _stack = res.stacktraceOrNull;
    }
    _loading!.complete();
    notifyListeners();
  }

  Future<SourcePath> _loadSource(EpisodePath eppath) async {
    if (tok?.isDisposed ?? true) {
      tok = CancelToken();
    }
    final srcExt = locate<SourceExtension>();
    return await srcExt.source(eppath, token: tok);
  }

  @override
  Future<void> dispose() async {
    if (tok?.isDisposed ?? true) {
      tok = null;
    }
    await tok?.cancel();
    tok?.dispose();
    tok = null;
    if (!(_loading?.isCompleted ?? true)) {
      _loading?.complete();
    }
    _loading = null;
    super.dispose();
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }
}
