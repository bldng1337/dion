import 'dart:async';
import 'dart:math';

import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/cache.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';

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
  Link? get cover => episode.cover ?? entry.cover;

  Future<void> goPrev(SourceSupplier supplier) async {
    if (!hasprev) return;
    await supplier.setEpisodeByIndex(episodenumber - 1);
  }

  Future<void> save() =>
      entry is EntrySaved ? (entry as EntrySaved).save() : Future.value();

  Future<void> goNext(SourceSupplier supplier) async {
    if (!hasnext) return;
    await supplier.setEpisodeByIndex(episodenumber + 1);
  }

  void go(BuildContext context) {
    GoRouter.of(context).push('/view', extra: [this]);
  }

  EpisodePath get next => EpisodePath(entry, episodenumber + 1);
  EpisodePath get prev => EpisodePath(entry, episodenumber - 1);
  Extension? get extension => entry.extension;
  String get extensionid => entry.boundExtensionId;

  Future<SourcePath> loadSource(CancelToken? tok) async {
    final srcExt = locate<ExtensionService>();
    final res = await srcExt.source(this, token: tok);
    return res;
  }

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
  late final DionMapCache<EpisodePath, SourcePath> cache;
  EpisodePath _episode;
  CancelToken tok = CancelToken();

  SourceSupplier(this._episode) {
    cache = DionMapCache.fromsize(maximumSize: 5, loader: _loadSource);
  }

  Future<SourcePath> getIndex(int index) async {
    final entry = _episode.entry;
    if (index < 0 || index >= entry.episodes.length) {
      throw RangeError.index(index, entry.episodes, 'index');
    }
    final eppath = EpisodePath(entry, index);
    return await cache.get(eppath).getOrThrow;
  }

  Future<void> setEpisodeByIndex(int index) async {
    final entry = episode.entry;
    if (index < 0 || index >= entry.episodes.length) {
      throw RangeError.index(index, entry.episodes, 'index');
    }
    episode.data.finished = true;
    if (entry is EntrySaved) {
      final download = locate<DownloadService>();
      download.download(
        Iterable.generate(
          min(
                entry.savedSettings.downloadNextEpisodes.value +
                    _episode.episodenumber,
                episode.entry.episodes.length - 1,
              ) -
              episode.episodenumber,
          (index) => EpisodePath(entry, episode.episodenumber + 1 + index),
        ),
      );
      if (entry.savedSettings.deleteOnFinish.value) {
        download.deleteEpisode(episode);
      }
    }
    episode.save();
    episode = EpisodePath(entry, index);
  }

  Future<SourcePath> _loadSource(EpisodePath eppath) async {
    final download = locate<DownloadService>();
    final dowloadStatus = await download.getCurrentStatus(
      eppath,
    ); //Do we really want to wait for the download to finish? In case it is large the user could still stream it while downloading but that would stress the server more
    if (dowloadStatus.task?.task != null) {
      await dowloadStatus.task?.task;
    }
    if (await download.isDownloaded(eppath)) {
      try {
        return SourcePath(eppath, (await download.getDownloaded(eppath))!);
      } catch (e, stack) {
        logger.e(
          'Error loading downloaded source',
          error: e,
          stackTrace: stack,
        );
      }
    }
    if (tok.isDisposed) {
      tok = CancelToken();
    }
    return eppath.loadSource(null);
  }

  set episode(EpisodePath path) {
    if (_episode == path) return;
    _episode = path;
    cache.preload(
      path,
    ); // We preload here as we dont care about the return but just want to load the data if it is not loaded
    notifyListeners();
  }

  EpisodePath get episode => _episode;
  SourcePath? get source => cache.getValue(_episode)?.getOrNull;
  Result<SourcePath>? get sourceResult => cache.getValue(_episode);
  Future<Result<SourcePath>> get sourceFuture => cache.get(_episode);

  @override
  Future<void> dispose() async {
    if (!tok.isDisposed) {
      await tok.cancel();
      tok.dispose();
    }
    super.dispose();
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }
}
