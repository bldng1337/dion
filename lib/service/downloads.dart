import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/image_store.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/ratelimit.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show Row;
import 'package:rhttp/rhttp.dart' as rhttp;

/// v3 keys episode folders by episode id.
const downloadVersion = 3;

void _indexChapters(Map<String, dynamic> index, List<Chapter>? chapters) {
  if (chapters == null || chapters.isEmpty) return;
  index['chapters'] = [
    for (final chapter in chapters)
      {
        'title': chapter.title,
        'start': chapter.start,
        'end': chapter.end,
        'kind': chapter.kind?.name,
      },
  ];
}

List<Chapter>? _chaptersFromIndex(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  return [
    for (final entry in raw)
      if (entry is Map)
        Chapter(
          title: entry['title'] as String? ?? '',
          start: (entry['start'] as num?)?.toDouble() ?? 0,
          end: (entry['end'] as num?)?.toDouble(),
          kind: ChapterKind.values
              .where((kind) => kind.name == entry['kind'])
              .firstOrNull,
        ),
  ];
}

List<ImageListAudio>? _audioFromIndex(dynamic raw, Directory dir) {
  if (raw is! List) return null;
  return [
    for (final e in raw)
      ImageListAudio(
        from: e['from'] as int,
        to: e['to'] as int,
        link: Link(url: dir.getFile(e['name'] as String).fileURL),
      ),
  ];
}

class DownloadTask extends Task {
  final EpisodePath ep;

  final Episode episode;
  final Directory _dir;
  final CancelToken token = CancelToken();
  final rhttp.CancelToken rhttpToken = rhttp.CancelToken();
  DownloadTask(this.ep)
    : episode = ep.episode,
      _dir = DownloadService._getDownloadPath(ep),
      super('Downloading ${ep.episode.name}');

  bool matches(EpisodePath other) =>
      _dir.path == DownloadService._getDownloadPath(other).path;

  Map<String, dynamic> get _episodeInfo => {
    'id': episode.id.uid,
    'name': episode.name,
  };

  Future<List<Map<String, dynamic>>> _downloadAudioSpans(
    Directory dir,
    List<ImageListAudio> spans,
  ) async {
    status = 'Downloading Audio';
    final result = <Map<String, dynamic>>[];
    for (final (index, span) in spans.indexed) {
      final file = await InternetFile.streamToFile(
        span.link.url,
        InternetFile.fromURI(span.link.url, dir, filename: 'audio$index'),
        headers: span.link.header,
        onReceiveProgress: (current) =>
            progress = (index + current) / spans.length,
        rhttpToken: rhttpToken,
        resolveEnding: true,
      );
      result.add({'name': file.filename, 'from': span.from, 'to': span.to});
    }
    progress = null;
    return result;
  }

  Future<List<Map<String, dynamic>>> _downloadSubtitles(
    Directory dir,
    List<Subtitles> subs,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (final (index, sub) in subs.indexed) {
      try {
        final file = await InternetFile.streamToFile(
          sub.url.url,
          InternetFile.fromURI(sub.url.url, dir, filename: 'subtitle$index'),
          headers: sub.url.header,
          rhttpToken: rhttpToken,
        );
        result.add({
          'filename': file.filename,
          'title': sub.title,
          'lang': sub.lang,
        });
      } catch (e, stack) {
        if (rhttpToken.isCancelled) rethrow;
        logger.w('Failed to download subtitle', error: e, stackTrace: stack);
      }
    }
    return result;
  }

  Future<void> handleMetadata(Directory dir) async {
    final cover = episode.cover;
    if (cover != null) {
      status = 'Fetching Thumbnail';
      await InternetFile.streamToFile(
        cover.url,
        InternetFile.fromURI(cover.url, dir, filename: 'cover'),
        headers: cover.header,
        onReceiveProgress: (current) => progress = current,
        rhttpToken: rhttpToken,
        resolveEnding: true,
      );
      progress = null;
    }
  }

  static List<Link> _paragraphImageLinks(List<Paragraph> paragraphs) {
    final links = <String, Link>{};
    for (final paragraph in paragraphs) {
      _mapParagraphImages(paragraph, (image) {
        links.putIfAbsent(image.url, () => image);
        return image;
      });
    }
    return links.values
        .where(
          (e) => e.url.startsWith('http://') || e.url.startsWith('https://'),
        )
        .toList();
  }

  static Paragraph _mapParagraphImages(
    Paragraph paragraph,
    Link Function(Link image) replace,
  ) {
    return switch (paragraph) {
      Paragraph_Text() => paragraph,
      Paragraph_Mixed(:final content) => paragraph.copyWith(
        content: content
            .map((e) => _mapMixedContentImages(e, replace))
            .toList(),
      ),
      Paragraph_CustomUI(:final ui) => paragraph.copyWith(
        ui: _mapCustomUIImages(ui, replace),
      ),
      Paragraph_Table(:final columns) => paragraph.copyWith(
        columns: columns
            .map(
              (row) => Row(
                cells: row.cells
                    .map((e) => _mapParagraphImages(e, replace))
                    .toList(),
              ),
            )
            .toList(),
      ),
    };
  }

  static MixedContent _mapMixedContentImages(
    MixedContent content,
    Link Function(Link image) replace,
  ) {
    return switch (content) {
      MixedContent_Text() => content,
      MixedContent_CustomUI(:final ui) => content.copyWith(
        ui: _mapCustomUIImages(ui, replace),
      ),
      MixedContent_Table(:final columns) => content.copyWith(
        columns: columns
            .map(
              (row) => Row(
                cells: row.cells
                    .map((e) => _mapParagraphImages(e, replace))
                    .toList(),
              ),
            )
            .toList(),
      ),
    };
  }

  static CustomUI _mapCustomUIImages(
    CustomUI ui,
    Link Function(Link image) replace,
  ) {
    return switch (ui) {
      CustomUI_Image(:final image) => ui.copyWith(image: replace(image)),
      // Card's top/bottom are CustomUIs too, so they can carry images.
      CustomUI_Card(:final image, :final top, :final bottom) => ui.copyWith(
        image: replace(image),
        top: _mapCustomUIImages(top, replace),
        bottom: _mapCustomUIImages(bottom, replace),
      ),
      CustomUI_Slot(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Column(:final children) => ui.copyWith(
        children: children.map((e) => _mapCustomUIImages(e, replace)).toList(),
      ),
      CustomUI_Row(:final children) => ui.copyWith(
        children: children.map((e) => _mapCustomUIImages(e, replace)).toList(),
      ),
      CustomUI_Padding(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Container(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Clickable(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Expanded(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_SizedBox(:final child?) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Wrap(:final children) => ui.copyWith(
        children: children.map((e) => _mapCustomUIImages(e, replace)).toList(),
      ),
      CustomUI_Center(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Align(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      CustomUI_Stack(:final children) => ui.copyWith(
        children: children.map((e) => _mapCustomUIImages(e, replace)).toList(),
      ),
      CustomUI_ListTile(
        :final leading,
        :final title,
        :final subtitle,
        :final trailing,
      ) =>
        ui.copyWith(
          leading: leading == null
              ? null
              : _mapCustomUIImages(leading, replace),
          title: title == null ? null : _mapCustomUIImages(title, replace),
          subtitle: subtitle == null
              ? null
              : _mapCustomUIImages(subtitle, replace),
          trailing: trailing == null
              ? null
              : _mapCustomUIImages(trailing, replace),
        ),
      CustomUI_Badge(:final child) => ui.copyWith(
        child: _mapCustomUIImages(child, replace),
      ),
      // All remaining variants are imageless leaves.
      _ => ui,
    };
  }

  @override
  Future<void> onRun() async {
    if (token.isDisposed) return;
    if (rhttpToken.isCancelled) return;
    final download = locate<DownloadService>();
    await download._ratelimitFor(ep).acquire();
    final position = ep.entry.episodes.indexWhere(
      (e) => e.id.uid == episode.id.uid,
    );
    if (position == -1) {
      throw StateError('${episode.name} is no longer listed by the source');
    }
    final dir = _dir;
    await dir.create(recursive: true);
    // Written before any content so an interrupted download can be told
    // apart from a finished one by the finished flag flipping to true.
    await dir
        .getFile('index.json')
        .writeAsString(
          jsonEncode({
            'version': downloadVersion,
            'finished': false,
            'episode': _episodeInfo,
          }),
        );
    await handleMetadata(dir);

    status = 'Fetching Source';
    final source = await EpisodePath(ep.entry, position).loadSource(token);

    final Map<String, dynamic> index = {
      'version': downloadVersion,
      'episode': _episodeInfo,
    };

    switch (source.source) {
      case final Source_Paragraphlist paragraphs:
        index['type'] = 'paragraphlist';
        final images = _paragraphImageLinks(paragraphs.paragraphs);
        final localImages = <String, Link>{};
        if (images.isNotEmpty) {
          status = 'Downloading Images';
          for (final (index, image) in images.indexed) {
            final file = await InternetFile.streamToFile(
              image.url,
              InternetFile.fromURI(image.url, dir, filename: 'image$index'),
              headers: image.header,
              onReceiveProgress: (current) =>
                  progress = (index + current) / images.length,
              rhttpToken: rhttpToken,
              resolveEnding: true,
            );
            localImages[image.url] = Link(url: file.fileURL);
          }
          progress = null;
        }
        if (paragraphs.audio case final spans?) {
          index['audio'] = await _downloadAudioSpans(dir, spans);
        }
        status = 'Writing Content';
        await dir
            .getFile('data.txt')
            .writeAsString(
              jsonEncode(
                paragraphs.paragraphs
                    .map(
                      (e) => _mapParagraphImages(
                        e,
                        (image) => localImages[image.url] ?? image,
                      ),
                    )
                    .map((e) => e.toJson())
                    .toList(),
              ),
            );
      case final Source_Epub data:
        status = 'Downloading Epub';
        final filename = await InternetFile.streamToFile(
          data.link.url,
          InternetFile.fromURI(
            data.link.url,
            dir,
            filename: 'data',
            ending: '.epub',
          ),
          headers: data.link.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['type'] = 'epub';
        index['filename'] = filename.filename;
      case final Source_Pdf data:
        status = 'Downloading PDF';
        final filename = await InternetFile.streamToFile(
          data.link.url,
          InternetFile.fromURI(
            data.link.url,
            dir,
            filename: 'data',
            ending: '.pdf',
          ),
          headers: data.link.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['type'] = 'pdf';
        index['filename'] = filename.filename;
      case final Source_Imagelist data:
        status = 'Downloading Images';
        index['type'] = 'imagelist';
        final imagedata = [];
        for (final (index, image) in data.links.indexed) {
          final file = await InternetFile.streamToFile(
            image.url,
            InternetFile.fromURI(image.url, dir, filename: 'image$index'),
            headers: image.header,
            onReceiveProgress: (current) =>
                progress = (index + current) / data.links.length,
            rhttpToken: rhttpToken,
            resolveEnding: true,
          );
          imagedata.add(file.filename);
        }
        index['images'] = imagedata;
        if (data.audio case final spans?) {
          index['audio'] = await _downloadAudioSpans(dir, spans);
        }
      case final Source_Video data:
        status = 'Downloading Video';
        final source = data.sources[0];
        final media = await InternetFile.downloadMedia(
          source.url.url,
          InternetFile.fromURI(source.url.url, dir, filename: 'video'),
          headers: source.url.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['type'] = media.isPlaylist ? 'm3u8' : 'video';
        index['lang'] = source.lang;
        index['name'] = source.name;
        index['filename'] = media.file.filename;
        _indexChapters(index, data.chapters);
        status = 'Downloading Subtitles';
        index['subtitles'] = await _downloadSubtitles(dir, data.sub);
      case final Source_Audio data:
        status = 'Downloading Audio';
        final source = data.sources[0];
        final media = await InternetFile.downloadMedia(
          source.url.url,
          InternetFile.fromURI(source.url.url, dir, filename: 'audio'),
          headers: source.url.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['type'] = 'audio';
        index['lang'] = source.lang;
        index['name'] = source.name;
        index['filename'] = media.file.filename;
        _indexChapters(index, data.chapters);
    }
    index['finished'] = true;
    await dir.getFile('index.json').writeAsString(jsonEncode(index));
    locate<DownloadService>().downloadsRevision++;
  }

  @override
  void onFailed(Object? error) {
    locate<DownloadService>().downloadsRevision++;
    final dir = _dir;
    if (dir.existsSync()) {
      dir
          .delete(recursive: true)
          .then(
            (_) {},
            onError: (Object e) {
              logger.e('Failed to delete partial download', error: e);
            },
          );
    }
  }

  @override
  Future<void> onCancel() async {
    token.cancel();
    token.dispose();
    rhttpToken.cancel();
    // Task.run deliberately skips onFailed when a task is cancelled, so the
    // partial download directory has to be removed here; otherwise it would
    // be mistaken for a finished download.
    locate<DownloadService>().downloadsRevision++;
    final dir = _dir;
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        logger.e('Failed to delete cancelled download', error: e);
      }
    }
  }
}

enum Status { nodownload, downloading, downloaded }

class DownloadedEpisode {
  final Directory path;

  final int? number;
  final String? name;
  final int size;
  final bool finished;
  const DownloadedEpisode({
    required this.path,
    required this.number,
    required this.name,
    required this.size,
    required this.finished,
  });
}

class DownloadedEntry {
  final Directory path;
  final EntrySaved? entry;
  final List<DownloadedEpisode> episodes;
  const DownloadedEntry({
    required this.path,
    required this.entry,
    required this.episodes,
  });
  int get size => episodes.fold(0, (sum, ep) => sum + ep.size);
}

class DownloadStatus {
  final Status status;
  final Task? task;
  const DownloadStatus(this.status, {this.task});

  @override
  String toString() {
    return 'DownloadStatus{status: $status, task: $task}';
  }

  bool get isDownloadingOrDownloaded =>
      status == Status.downloading || status == Status.downloaded;
}

class DownloadService {
  final Map<String, Ratelimit> _ratelimits = {};

  // Bumped whenever downloads change on disk, so consumers can cache
  // state derived from [downloadedEntryKeys].
  int downloadsRevision = 0;

  /// Task starts are paced per extension so one source's politeness delay
  /// doesn't throttle unrelated extensions.
  Ratelimit _ratelimitFor(EpisodePath ep) {
    return _ratelimits.putIfAbsent(
      ep.extensionid,
      () => LeakyBucketRatelimit.fromRate(1),
    );
  }

  static Future<void> ensureInitialized() async {
    final service = DownloadService();
    register<DownloadService>(service);
    unawaited(service._sweepDeadDownloads());
  }

  Future<void> _sweepDeadDownloads() async {
    try {
      final root = (await locateAsync<DirectoryProvider>()).downloadspath;
      if (!await root.exists()) return;
      final dead = <Directory>[];
      await for (final ext in root.list()) {
        if (ext is! Directory) continue;
        await for (final entry in ext.list()) {
          if (entry is! Directory) continue;
          await for (final episode in entry.list()) {
            if (episode is Directory && await _readIndex(episode) == null) {
              dead.add(episode);
            }
          }
        }
      }
      // A download queued while this walk ran is partial but very much alive.
      final active = _activeDownloadPaths();
      dead.removeWhere((dir) => active.contains(dir.path));
      if (dead.isEmpty) return;
      logger.i('Removing ${dead.length} dead download folders');
      await deleteDownloadDirs(dead);
    } catch (e, stack) {
      logger.w('Sweeping dead downloads failed', error: e, stackTrace: stack);
    }
  }

  Future<void> download(Iterable<EpisodePath> eps) async {
    logger.i('Downloading ${eps.length} episodes');
    try {
      for (final ep in eps) {
        if ((await getCurrentStatus(ep)).isDownloadingOrDownloaded) {
          continue;
        }
        final mngr = locate<TaskManager>();
        mngr.root
            .createOrGetCategory('download', 'Download', concurrency: null)
            .createOrGetCategory(
              ep.extensionid,
              ep.extension?.name ?? 'Unknown',
            )
            .enqueue(DownloadTask(ep));
      }
    } catch (e, stack) {
      logger.e('Error downloading episode', error: e, stackTrace: stack);
    }
  }

  Future<DownloadStatus> getCurrentStatus(EpisodePath ep) async {
    final mngr = locate<TaskManager>();
    if (await isDownloaded(ep)) {
      return const DownloadStatus(Status.downloaded);
    }
    final task = mngr.getTask(
      (e) => e is DownloadTask && e.matches(ep),
      categoryids: ['download', ep.extensionid],
    );
    return DownloadStatus(
      task != null ? Status.downloading : Status.nodownload,
      task: task,
    );
  }

  Stream<DownloadStatus> getStatus(EpisodePath ep) {
    final mngr = locate<TaskManager>();
    final stream = mngr.onTaskChange(
      (e) => e is DownloadTask && e.matches(ep),
      categoryids: ['download', ep.extensionid],
    );
    StreamSubscription<FileSystemEvent>? filewatcher;
    // Cancelling the subscription does not close the controller, so
    // controller.isClosed is never true; track cancellation explicitly so
    // the async exists() check below does not install a watcher nobody
    // will ever cancel.
    var cancelled = false;
    final controller = StreamController<DownloadStatus>();
    controller.onListen = () {
      final sub = stream.listen((task) {
        if (task != null) {
          controller.add(DownloadStatus(Status.downloading, task: task));
          return;
        }
        final path = _getDownloadPath(ep);
        _readIndex(path)
            .then((index) {
              if (cancelled) return;
              // Cancel any previous watcher before (re)assigning so repeated
              // status transitions don't leak native file-system watchers.
              filewatcher?.cancel();
              filewatcher = null;
              if (index != null) {
                controller.add(const DownloadStatus(Status.downloaded));
                filewatcher = path.watch(events: FileSystemEvent.delete).listen(
                  (event) {
                    controller.add(const DownloadStatus(Status.nodownload));
                  },
                );
              } else {
                controller.add(const DownloadStatus(Status.nodownload));
              }
            })
            .catchError((e) {
              logger.e('Error watching download path', error: e);
            });
      });

      controller.onCancel = () {
        cancelled = true;
        sub.cancel();
        filewatcher?.cancel();
        filewatcher = null;
      };
    };
    return controller.stream;
  }

  /// Reads and validates a download index: null when missing, unreadable,
  /// written by an incompatible version, or for an interrupted download.
  static Future<Map<String, dynamic>?> _readIndex(Directory dir) async {
    try {
      final index = jsonDecode(await dir.getFile('index.json').readAsString());
      if (index is! Map) return null;
      if (index['version'] != downloadVersion) return null;
      if (index['finished'] != true) return null;
      return Map<String, dynamic>.from(index);
    } catch (_) {
      // A missing or broken index belongs to an interrupted download.
      return null;
    }
  }

  Future<bool> isDownloaded(EpisodePath ep) async {
    return await _readIndex(_getDownloadPath(ep)) != null;
  }

  Future<Source?> getDownloaded(EpisodePath ep) async {
    final path = _getDownloadPath(ep);
    if (!await path.exists()) return null;
    final index = await _readIndex(path);
    if (index == null) return null;
    switch (index['type']) {
      case 'paragraphlist':
        return Source.paragraphlist(
          paragraphs: (json.decode(
            await path.getFile('data.txt').readAsString(),
          ) as List<dynamic>).map((e) => JsonParagraph.fromJson(e)).toList(),
          audio: _audioFromIndex(index['audio'], path),
        );
      case 'epub':
        return Source.epub(
          link: Link(url: path.getFile(index['filename'] as String).fileURL),
        );
      case 'pdf':
        return Source.pdf(
          link: Link(url: path.getFile(index['filename'] as String).fileURL),
        );
      case 'imagelist':
        final images = index['images'] as List<dynamic>;
        return Source.imagelist(
          links: images
              .map((e) => Link(url: path.getFile(e as String).fileURL))
              .toList(),
          audio: _audioFromIndex(index['audio'], path),
        );
      case 'audio':
        final file = _mediaFile(index, path);
        if (file == null || !await file.exists()) {
          return null;
        }
        return Source.audio(
          sources: [
            StreamSource(
              url: Link(url: file.fileURL),
              lang: index['lang'] as String,
              name: index['name'] as String,
            ),
          ],
          chapters: _chaptersFromIndex(index['chapters']),
        );
      case 'm3u8':
      case 'video':
        final file = _mediaFile(index, path);
        if (file == null || !await file.exists()) {
          return null;
        }
        return Source.video(
          sources: [
            StreamSource(
              url: Link(url: file.fileURL),
              lang: index['lang'] as String,
              name: index['name'] as String,
            ),
          ],
          sub: [
            for (final sub in (index['subtitles'] as List<dynamic>?) ?? [])
              Subtitles(
                title: sub['title'] as String,
                lang: sub['lang'] as String,
                url: Link(url: path.getFile(sub['filename'] as String).fileURL),
              ),
          ],
          chapters: _chaptersFromIndex(index['chapters']),
        );
      default:
        return null;
    }
  }

  static File? _mediaFile(Map<String, dynamic> index, Directory path) {
    final filename = index['filename'];
    if (filename is! String) return null;
    return path.getFile(filename);
  }

  static Directory _getDownloadPath(EpisodePath ep) {
    return _entryDownloadPath(
      ep.entry,
    ).sub(pathEncode(ep.episode.id.uid));
  }

  static Directory _entryDownloadPath(EntryDetailed entry) {
    return locate<DirectoryProvider>().downloadspath
        .sub(pathEncode(entry.boundExtensionId))
        .sub(pathEncode(entry.id.uid));
  }

  Future<void> deleteEpisodes(Iterable<EpisodePath> eps) async {
    logger.i('Deleting ${eps.length} episodes');
    for (final ep in eps) {
      await deleteEpisode(ep);
    }
  }

  Future<void> deleteEpisode(EpisodePath ep) async {
    final path = _getDownloadPath(ep);
    if (!await path.exists()) {
      return;
    }
    await path.delete(recursive: true);
    downloadsRevision++;
  }

  Future<void> deleteExtension(Extension ext) async {
    final path = locate<DirectoryProvider>().downloadspath;
    if (!await path.exists()) {
      return;
    }
    final extensionPath = path.sub(pathEncode(ext.id));
    if (!await extensionPath.exists()) {
      return;
    }
    await extensionPath.delete(recursive: true);
    downloadsRevision++;
  }

  Future<void> deleteEntry(EntryDetailed entry) async {
    final path = locate<DirectoryProvider>().downloadspath;
    if (!await path.exists()) {
      return;
    }
    final downloadpath = path
        .sub(pathEncode(entry.boundExtensionId))
        .sub(pathEncode(entry.id.uid));
    if (!await downloadpath.exists()) {
      return;
    }
    await downloadpath.delete(recursive: true);
    downloadsRevision++;
  }

  /// Keys (`pathEncode(extensionid)` + `/` + `pathEncode(entry uid)`) of
  /// entries with at least one finished download on disk. Directory names
  /// carry one-way sanitised ids, so they can only be matched by re-encoding
  /// entry ids, never decoded.
  Future<Set<String>> downloadedEntryKeys() async {
    final downloadsDir = locate<DirectoryProvider>().downloadspath;
    if (!await downloadsDir.exists()) return {};
    final keys = <String>{};
    await for (final extEntity in downloadsDir.list()) {
      if (extEntity is! Directory) continue;
      await for (final entryEntity in extEntity.list()) {
        if (entryEntity is! Directory) continue;
        if (await _hasFinishedEpisode(entryEntity)) {
          keys.add('${extEntity.name}/${entryEntity.name}');
        }
      }
    }
    return keys;
  }

  Future<bool> _hasFinishedEpisode(Directory entrydir) async {
    await for (final entity in entrydir.list()) {
      if (entity is! Directory) continue;
      if (await _isFinished(entity)) return true;
    }
    return false;
  }

  Future<List<DownloadedEntry>> listDownloads() async {
    final downloadsDir = locate<DirectoryProvider>().downloadspath;
    if (!await downloadsDir.exists()) return [];

    // Directories of in-flight downloads only hold partial data and are
    // managed by their task; hide them until the task finishes or cleans up.
    final active = _activeDownloadPaths();

    // Directory names are sanitised one-way, so entries can only be matched
    // by re-encoding their ids, never by decoding the directory name.
    final entriesByKey = <String, EntrySaved>{};
    final db = locate<Database>();
    var page = 0;
    while (true) {
      final batch = await db.getEntries(page++, 100).toList();
      if (batch.isEmpty) break;
      for (final entry in batch) {
        entriesByKey.putIfAbsent(
          '${pathEncode(entry.boundExtensionId)}/${pathEncode(entry.id.uid)}',
          () => entry,
        );
      }
    }

    final result = <DownloadedEntry>[];
    await for (final extEntity in downloadsDir.list()) {
      if (extEntity is! Directory) continue;
      await for (final entryEntity in extEntity.list()) {
        if (entryEntity is! Directory) continue;
        final episodes = <DownloadedEpisode>[];
        await for (final epEntity in entryEntity.list()) {
          if (epEntity is! Directory) continue;
          if (active.contains(epEntity.path)) continue;
          final savedEpisodes =
              entriesByKey['${extEntity.name}/${entryEntity.name}']?.episodes;
          final position = savedEpisodes?.indexWhere(
            (e) => pathEncode(e.id.uid) == epEntity.name,
          );
          episodes.add(
            DownloadedEpisode(
              path: epEntity,
              number: position == null || position < 0 ? null : position,
              name: await _episodeName(epEntity),
              size: await getDirectorySize(epEntity),
              finished: await _isFinished(epEntity),
            ),
          );
        }
        if (episodes.isEmpty) continue;
        episodes.sort((a, b) => (a.number ?? -1).compareTo(b.number ?? -1));
        result.add(
          DownloadedEntry(
            path: entryEntity,
            entry: entriesByKey['${extEntity.name}/${entryEntity.name}'],
            episodes: episodes,
          ),
        );
      }
    }
    result.sort((a, b) => b.size.compareTo(a.size));
    return result;
  }

  Future<bool> _isFinished(Directory dir) async {
    return await _readIndex(dir) != null;
  }

  Future<String?> _episodeName(Directory dir) async {
    try {
      final index = jsonDecode(await dir.getFile('index.json').readAsString());
      return index['episode']?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteDownloadDirs(Iterable<Directory> dirs) async {
    final downloadsDir = locate<DirectoryProvider>().downloadspath;
    for (final dir in dirs) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await _pruneEmptyParents(dir.parent, downloadsDir);
    }
    downloadsRevision++;
  }

  Future<void> _pruneEmptyParents(Directory dir, Directory root) async {
    var current = dir;
    while (current.path != root.path) {
      try {
        if (!await current.exists() || !await current.list().isEmpty) return;
        await current.delete();
      } catch (e) {
        logger.w('Failed to prune empty download directory', error: e);
        return;
      }
      current = current.parent;
    }
  }
}

Set<String> _activeDownloadPaths() {
  if (!has<TaskManager>()) return const {};
  return {
    for (final task
        in locate<TaskManager>().root.traverseBreathFirst().expand(
          (cat) => cat.tasks,
        ))
      if (task is DownloadTask && !task.finished) task._dir.path,
  };
}

Future<void> pruneHangingDownloads(EntryDetailed entry) async {
  // An empty list is far more likely a broken source than a wiped entry.
  if (entry.episodes.isEmpty) return;
  try {
    final dir = DownloadService._entryDownloadPath(entry);
    if (!await dir.exists()) return;
    final listed = {for (final e in entry.episodes) pathEncode(e.id.uid)};
    final active = _activeDownloadPaths();
    var removed = false;
    await for (final child in dir.list()) {
      if (child is! Directory) continue;
      if (listed.contains(child.name) || active.contains(child.path)) continue;
      logger.i('Removing hanging download ${child.path}');
      await child.delete(recursive: true);
      removed = true;
    }
    if (removed && has<DownloadService>()) {
      locate<DownloadService>().downloadsRevision++;
    }
  } catch (e, stack) {
    logger.w('Checking for hanging downloads failed', error: e, stackTrace: stack);
  }
}

String pathEncode(String path) => ImageStoreService.hashUrl(path);
