import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/ratelimit.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

const downloadVersion = 1;

class DownloadTask extends Task {
  final EpisodePath ep;
  final CancelToken token = CancelToken();
  final rhttp.CancelToken rhttpToken = rhttp.CancelToken();
  DownloadTask(this.ep) : super('Downloading ${ep.episode.name}');

  Future<void> handleMetadata(Directory dir) async {
    if (ep.episode.cover != null) {
      status = 'Fetching Thumbnail';
      await streamToFile(
        ep.episode.cover!,
        'cover',
        dir,
        headers: ep.episode.coverHeader,
        onReceiveProgress: (current) => progress = current,
      );
      progress = null;
    }
  }

  @override
  Future<void> onRun() async {
    if (token.isDisposed) return;
    if (rhttpToken.isCancelled) return;
    final download = locate<DownloadService>();
    await download.ratelimit.acquire();
    final dir = DownloadService._getDownloadPath(ep);
    await dir.create(recursive: true);
    await handleMetadata(dir);

    status = 'Fetching Source';
    final source = await ep.loadSource(token);

    final Map<String, dynamic> index = {'version': downloadVersion};
    switch (source.source) {
      case final Source_Data source:
        switch (source.sourcedata) {
          case final DataSource_Paragraphlist paragraphs:
            index['type'] = 'paragraphlist';
            status = 'Writing Content';
            await dir
                .getFile('data.txt')
                .writeAsString(jsonEncode(paragraphs.paragraphs));
        }
      case final Source_Directlink source:
        switch (source.sourcedata) {
          case final LinkSource_Epub data:
            status = 'Downloading Epub';
            final filename = await streamToFile(
              data.link,
              'data',
              dir,
              onReceiveProgress: (current) => progress = current,
            );
            progress = null;
            index['filetype'] = 'epub';
            index['filename'] = filename;
          case final LinkSource_Pdf data:
            status = 'Downloading PDF';
            final filename = await streamToFile(
              data.link,
              'data',
              dir,
              onReceiveProgress: (current) => progress = current,
            );
            progress = null;
            index['filetype'] = 'pdf';
            index['filename'] = filename;
          case final LinkSource_Imagelist data:
            status = 'Downloading Images';
            index['type'] = 'imagelist';
            final imagedata = [];
            for (final (index, image) in data.links.indexed) {
              final name = await streamToFile(
                image,
                'image$index',
                dir,
                onReceiveProgress: (current) =>
                    progress = (index + current) / data.links.length,
                headers: data.header,
              );
              progress = null;
              imagedata.add(name);
            }
            index['images'] = imagedata;
            if (data.audio != null) {
              status = 'Downloading Audio';
              final audiodata = [];
              for (final (index, audio) in data.audio!.indexed) {
                final name = await streamToFile(
                  audio.link,
                  'audio$index',
                  dir,
                  onReceiveProgress: (current) =>
                      progress = (index + current) / data.audio!.length,
                  headers: data.header,
                );
                progress = null;
                audiodata.add({
                  'name': name,
                  'from': audio.from,
                  'to': audio.to,
                });
              }
              index['audio'] = audiodata;
            }
          case final LinkSource_M3u8 data:
            status = 'Downloading m3u8';
            final res = await downloadm3u8(
              data.link,
              'playlist',
              dir,
              headers: data.headers,
              onReceiveProgress: (current) => progress = current,
            );
            index['type'] = 'm3u8';
            index['playlist'] = res;
          case final LinkSource_Mp3 data:
            status = 'Downloading MP3';
            final audiodata = [];
            for (final (index, audio) in data.chapters.indexed) {
              final name = await streamToFile(
                audio.url,
                'audio$index',
                dir,
                onReceiveProgress: (current) =>
                    progress = (index + current) / data.chapters.length,
              );
              progress = null;
              audiodata.add({'title': audio.title, 'name': name});
            }
            index['type'] = 'mp3';
            index['audio'] = audiodata;
        }
    }
    await dir.getFile('index.json').writeAsString(jsonEncode(index));
  }

  Function(int, int)? toRhttpProgress(
    void Function(double)? onReceiveProgress,
  ) {
    if (onReceiveProgress == null) return null;
    return (count, total) {
      if (total < 0) return;
      onReceiveProgress(count / total);
    };
  }

  Future<String> downloadm3u8(
    String link,
    String name,
    Directory dir, {
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
  }) async {
    final network = locate<NetworkService>();
    status = 'Fetching m3u8 file';
    final res = await network.client.get(
      link,
      headers: headers != null ? rhttp.HttpHeaders.rawMap(headers) : null,
      cancelToken: rhttpToken,
    );
    final m3u8 = res.body.split('\n');
    if (m3u8[0] != '#EXTM3U') {
      throw Exception('Invalid m3u8 file');
    }

    final contentdir = dir.sub(name);
    if (!await contentdir.exists()) {
      await contentdir.create(recursive: true);
    }
    status = 'Downloading m3u8 content';
    final playlist = m3u8.sublist(1);
    var part = 0;
    final urimatcher = RegExp('URI="(.*)"');
    final newplaylist = <String>[];
    for (var (index, e) in playlist.indexed) {
      onReceiveProgress?.call(index / playlist.length.toDouble());
      if (e.trim().isEmpty) continue;
      final links = e.startsWith('#')
          ? urimatcher
                .allMatches(e)
                .map((e) => e.group(1))
                .where((e) => e != null)
                .cast<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
          : [e];
      for (final artefactLink in links) {
        if (artefactLink.endsWith('.m3u8') || artefactLink.endsWith('.m3u')) {
          final res = await downloadm3u8(
            formatURI(artefactLink, link),
            'artefact$part',
            contentdir,
            headers: headers,
            onReceiveProgress: onReceiveProgress != null
                ? (progress) => onReceiveProgress(
                    (progress + index) / playlist.length.toDouble(),
                  )
                : null,
          );
          part++;
          e = e.replaceAll(
            artefactLink,
            contentdir.getFile(res).relativePath(dir),
          );
        } else {
          final res = await streamToFile(
            formatURI(artefactLink, link),
            'artefact$part',
            contentdir,
            headers: headers,
            onReceiveProgress: onReceiveProgress != null
                ? (progress) => onReceiveProgress(
                    (progress + index) / playlist.length.toDouble(),
                  )
                : null,
          );
          part++;
          e = e.replaceAll(
            artefactLink,
            contentdir.getFile(res).relativePath(dir),
          );
        }
      }
      newplaylist.add(e);
    }
    status = 'Writing m3u8 file';
    progress = null;
    final fileending = parseFileending(link) ?? 'm3u8';
    await dir
        .getFile('$name$fileending')
        .writeAsString('#EXTM3U\n${newplaylist.join('\n')}');
    return '$name$fileending';
  }

  String formatURI(String link, String location) {
    if (!['http://', 'https://'].any((e) => link.startsWith(e))) {
      return '${location.substring(0, location.lastIndexOf('/'))}/$link';
    }
    return link;
  }

  String? parseFileending(String link) {
    final dotIndex = link.lastIndexOf('.');
    if (dotIndex == -1) {
      return null;
    }
    final fileending = link.substring(dotIndex);
    if (fileending.isEmpty ||
        fileending.contains('/') ||
        fileending.contains('?')) {
      return null;
    }
    return fileending;
  }

  Future<String> streamToFile(
    String link,
    String name,
    Directory dir, {
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
  }) async {
    final network = locate<NetworkService>();
    final stream = await network.client.getStream(
      link,
      cancelToken: rhttpToken,
      onReceiveProgress: toRhttpProgress(onReceiveProgress),
      headers: headers != null ? rhttp.HttpHeaders.rawMap(headers) : null,
    );
    final fileending = parseFileending(link) ?? '';
    final file = dir.getFile('$name$fileending');
    await file.streamToFile(stream.body);

    return file.filename;
  }

  @override
  void onFailed(Object? error) {
    final dir = DownloadService._getDownloadPath(ep);
    if (dir.existsSync()) {
      dir.delete(recursive: true);
    }
  }

  @override
  Future<void> onCancel() async {
    token.cancel();
    token.dispose();
    rhttpToken.cancel();
  }
}

enum Status { nodownload, downloading, downloaded }

class DownloadStatus {
  final Status status;
  final Task? task;
  const DownloadStatus(this.status, {this.task});

  @override
  String toString() {
    return 'DownloadStatus{status: $status, task: $task}';
  }
}

class DownloadService {
  final Ratelimit ratelimit = LeakyBucketRatelimit.fromRate(1);

  Future<void> download(Iterable<EpisodePath> eps) async {
    try {
      for (final ep in eps) {
        if (await isDownloaded(ep)) {
          continue;
        }
        final mngr = locate<TaskManager>();
        mngr.root
            .createOrGetCategory('download', 'Download', concurrency: null)
            .createOrGetCategory(ep.extension.id, ep.extension.name)
            .enqueue(DownloadTask(ep));
      }
    } catch (e, stack) {
      logger.e('Error downloading episode', error: e, stackTrace: stack);
    }
  }

  Stream<DownloadStatus> getStatus(EpisodePath ep) {
    final mngr = locate<TaskManager>();
    final stream = mngr.onTaskChange(
      (e) => e is DownloadTask && e.ep == ep,
      categoryids: ['download', ep.extension.id],
    );
    StreamSubscription<FileSystemEvent>? filewatcher;
    final controller = StreamController<DownloadStatus>();
    controller.onListen = () {
      final sub = stream.listen((task) {
        if (task != null) {
          controller.add(DownloadStatus(Status.downloading, task: task));
          return;
        }
        final path = _getDownloadPath(ep);
        path
            .exists()
            .then((value) {
              if (controller.isClosed) return;
              if (value) {
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
        sub.cancel();
        filewatcher?.cancel();
      };
    };
    return controller.stream;
  }

  Future<bool> isDownloaded(EpisodePath ep) async {
    final path = _getDownloadPath(ep);
    return await path.exists();
  }

  Future<Source?> getDownloaded(EpisodePath ep) async {
    final path = _getDownloadPath(ep);
    if (await path.exists()) {
      final index = jsonDecode(await path.getFile('index.json').readAsString());
      if (index['version'] != downloadVersion) {
        return null;
      }
      switch (index['type']) {
        case 'paragraphlist':
          return Source.data(
            sourcedata: DataSource.paragraphlist(
              paragraphs:
                  (json.decode(await path.getFile('data.txt').readAsString())
                          as List<dynamic>)
                      .cast(),
            ),
          );
        case 'epub':
          return Source.directlink(
            sourcedata: LinkSource.epub(
              link: path.getFile(index['filename'] as String).fileURL,
            ),
          );
        case 'pdf':
          return Source.directlink(
            sourcedata: LinkSource.pdf(
              link: path.getFile(index['filename'] as String).fileURL,
            ),
          );
        case 'imagelist':
          final images = index['images'] as List<dynamic>;
          final audio = index['audio'] as List<dynamic>?;
          return Source.directlink(
            sourcedata: LinkSource.imagelist(
              links: images
                  .map((e) => path.getFile(e as String).fileURL)
                  .toList(),
              audio: audio
                  ?.map(
                    (e) => ImageListAudio(
                      from: e['from'] as int,
                      to: e['to'] as int,
                      link: path.getFile(e['name'] as String).fileURL,
                    ),
                  )
                  .toList(),
            ),
          );
        case 'mp3':
          final audio = index['audio'] as List<dynamic>;
          return Source.directlink(
            sourcedata: LinkSource.mp3(
              chapters: audio
                  .map(
                    (e) => UrlChapter(
                      title: e['title'] as String,
                      url: path.getFile(e['name'] as String).fileURL,
                    ),
                  )
                  .toList(),
            ),
          );
        case 'm3u8':
          final playlist = path.getFile(index['playlist'] as String);
          if (!await playlist.exists()) {
            return null;
          }
          return Source.directlink(
            sourcedata: LinkSource.m3U8(link: playlist.fileURL, sub: []),
          );
        default:
          return null;
      }
    }
    return null;
  }

  static Directory _getDownloadPath(EpisodePath ep) {
    final dir = locate<DirectoryProvider>().downloadspath;
    return dir
        .sub(pathEncode(ep.extension.id))
        .sub(pathEncode(ep.entry.id))
        .sub(pathEncode(ep.episodenumber.toString()));
  }

  Future<void> deleteEpisodes(Iterable<EpisodePath> eps) async {
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
  }

  Future<void> deleteExtension(Extension ext) async {
    final path = locate<DirectoryProvider>().downloadspath;
    if (!await path.exists()) {
      return;
    }
    await path.sub(pathEncode(ext.id)).delete(recursive: true);
  }

  Future<void> deleteEntry(EntryDetailed entry) async {
    final path = locate<DirectoryProvider>().downloadspath;
    if (!await path.exists()) {
      return;
    }
    await path
        .sub(pathEncode(entry.extension.id))
        .sub(pathEncode(entry.id))
        .delete(recursive: true);
  }

  static Future<void> ensureInitialized() async {
    register<DownloadService>(DownloadService());
  }
}

String pathEncode(String path) {
  return path
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>| }{}\-,]'), '')
      .replaceAll(RegExp('[_]{2,}'), '_');
}
