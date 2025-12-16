import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
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
    final cover = ep.episode.cover;
    if (cover != null) {
      status = 'Fetching Thumbnail';
      await InternetFile.streamToFile(
        cover.url,
        InternetFile.fromURI(cover.url, dir, filename: 'cover'),
        headers: cover.header,
        onReceiveProgress: (current) => progress = current,
        rhttpToken: rhttpToken,
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
      case final Source_Paragraphlist paragraphs:
        index['type'] = 'paragraphlist';
        status = 'Writing Content';
        await dir
            .getFile('data.txt')
            .writeAsString(
              jsonEncode(paragraphs.paragraphs.map((e) => e.toJson()).toList()),
            );
      case final Source_Epub data:
        status = 'Downloading Epub';
        final filename = await InternetFile.streamToFile(
          data.link.url,
          InternetFile.fromURI(data.link.url, dir, filename: 'data'),
          headers: data.link.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['filetype'] = 'epub';
        index['filename'] = filename;
      case final Source_Pdf data:
        status = 'Downloading PDF';
        final filename = await InternetFile.streamToFile(
          data.link.url,
          InternetFile.fromURI(data.link.url, dir, filename: 'data'),
          headers: data.link.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        progress = null;
        index['filetype'] = 'pdf';
        index['filename'] = filename;
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
          );
          progress = null;
          imagedata.add(file.filename);
        }
        index['images'] = imagedata;
        if (data.audio != null) {
          status = 'Downloading Audio';
          final audiodata = [];
          for (final (index, audio) in data.audio!.indexed) {
            final file = await InternetFile.streamToFile(
              audio.link.url,
              InternetFile.fromURI(
                audio.link.url,
                dir,
                filename: 'audio$index',
              ),
              headers: audio.link.header,
              onReceiveProgress: (current) =>
                  progress = (index + current) / data.audio!.length,
              rhttpToken: rhttpToken,
            );
            progress = null;
            audiodata.add({
              'name': file.filename,
              'from': audio.from,
              'to': audio.to,
            });
          }
          index['audio'] = audiodata;
        }
      case final Source_Video data:
        status = 'Downloading m3u8';
        //TODO: Better way to do this
        final source = data.sources[0];
        final file = await InternetFile.downloadm3u8(
          source.url.url,
          InternetFile.fromURI(source.url.url, dir, filename: 'playlist'),
          headers: source.url.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        index['type'] = 'm3u8';
        index['lang'] = source.lang;
        index['name'] = source.name;
        index['playlist'] = file.filename;
      case final Source_Audio data:
        status = 'Downloading MP3';
        final source = data.sources[0];
        final file = await InternetFile.downloadm3u8(
          source.url.url,
          InternetFile.fromURI(source.url.url, dir, filename: 'playlist'),
          headers: source.url.header,
          onReceiveProgress: (current) => progress = current,
          rhttpToken: rhttpToken,
        );
        index['type'] = 'mp3';
        index['lang'] = source.lang;
        index['name'] = source.name;
        index['playlist'] = file.filename;
    }
    await dir.getFile('index.json').writeAsString(jsonEncode(index));
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

  bool get isDownloadingOrDownloaded =>
      status == Status.downloading || status == Status.downloaded;
}

class DownloadService {
  final Ratelimit ratelimit = LeakyBucketRatelimit.fromRate(1);

  static Future<void> ensureInitialized() async {
    register<DownloadService>(DownloadService());
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
      (e) => e is DownloadTask && e.ep == ep,
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
      (e) => e is DownloadTask && e.ep == ep,
      categoryids: ['download', ep.extensionid],
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
          return Source.paragraphlist(
            paragraphs:
                (json.decode(await path.getFile('data.txt').readAsString())
                        as List<dynamic>)
                    .map((e) => JsonParagraph.fromJson(e))
                    .toList(),
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
          final audio = index['audio'] as List<dynamic>?;
          return Source.imagelist(
            links: images
                .map((e) => Link(url: path.getFile(e as String).fileURL))
                .toList(),
            audio: audio
                ?.map(
                  (e) => ImageListAudio(
                    from: e['from'] as int,
                    to: e['to'] as int,
                    link: Link(url: path.getFile(e['name'] as String).fileURL),
                  ),
                )
                .toList(),
          );
        case 'mp3':
          final playlist = path.getFile(index['playlist'] as String);
          if (!await playlist.exists()) {
            return null;
          }
          return Source.audio(
            sources: [
              StreamSource(
                url: Link(url: playlist.fileURL),
                lang: index['lang'] as String,
                name: index['name'] as String,
              ),
            ],
          );
        case 'm3u8':
          final playlist = path.getFile(index['playlist'] as String);
          if (!await playlist.exists()) {
            return null;
          }
          return Source.video(
            sources: [
              StreamSource(
                url: Link(url: playlist.fileURL),
                lang: index['lang'] as String,
                name: index['name'] as String,
              ),
            ],
            sub: [],
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
        .sub(pathEncode(ep.extensionid))
        .sub(pathEncode(ep.entry.id.uid))
        .sub(pathEncode(ep.episodenumber.toString()));
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
        .sub(pathEncode(entry.boundExtensionId))
        .sub(pathEncode(entry.id.uid))
        .delete(recursive: true);
  }
}

String pathEncode(String path) {
  return path
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>| }{}\-,]'), '')
      .replaceAll(RegExp('[_]{2,}'), '_');
}
