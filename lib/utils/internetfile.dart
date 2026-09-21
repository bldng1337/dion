import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart';
import 'package:uuid/v4.dart';

class InternetFile {
  static File fromURI(
    String link,
    Directory dir, {
    String? filename,
    String? ending,
  }) {
    final fileending = ending ?? _parseFileending(link) ?? '';
    if (filename != null) {
      return dir.getFile('$filename$fileending');
    }
    return dir.getFile(
      (_parseFilename(link) ?? 'Unknown-${const UuidV4().generate()}') +
          fileending,
    );
  }

  static Future<File> streamToFile(
    String link,
    File file, {
    CancelToken? rhttpToken,
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
    bool resolveEnding = false,
  }) async {
    final network = locate<NetworkService>();
    final stream = await network.client.getStream(
      link,
      cancelToken: rhttpToken,
      onReceiveProgress: _toRhttpProgress(onReceiveProgress),
      headers: headers != null ? HttpHeaders.rawMap(headers) : null,
    );
    final target = resolveEnding ? _resolveEnding(file, stream) : file;
    await target.streamToFile(stream.body);
    return target;
  }

  /// Extends `file` by the response's content type when the URL carried no
  /// file ending, so files don't land nameless on disk.
  static File _resolveEnding(File file, HttpResponse stream) {
    if (file.extension.isNotEmpty) return file;
    final ending = _endingForContentType(_contentType(stream));
    if (ending == null) return file;
    return file.parent.getFile('${file.filenameWithoutExtension}$ending');
  }

  static const _contentTypeEndings = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/gif': '.gif',
    'image/webp': '.webp',
    'image/avif': '.avif',
    'image/bmp': '.bmp',
    'audio/mpeg': '.mp3',
    'audio/mp4': '.m4a',
    'audio/x-m4a': '.m4a',
    'audio/x-m4b': '.m4b',
    'audio/ogg': '.ogg',
    'audio/opus': '.opus',
    'audio/flac': '.flac',
    'audio/x-flac': '.flac',
    'audio/wav': '.wav',
    'audio/x-wav': '.wav',
    'audio/aac': '.aac',
    'video/mp4': '.mp4',
    'video/webm': '.webm',
    'video/x-matroska': '.mkv',
    'video/quicktime': '.mov',
    'video/mpeg': '.mpeg',
    'application/pdf': '.pdf',
    'application/epub+zip': '.epub',
  };

  static String? _contentType(HttpResponse response) {
    for (final (name, value) in response.headers) {
      if (name.toLowerCase() == 'content-type') return value;
    }
    return null;
  }

  static String? _endingForContentType(String? contentType) {
    if (contentType == null) return null;
    return _contentTypeEndings[contentType.split(';').first.trim()];
  }

  /// Downloads a media source into `file`'s directory, transparently
  /// handling m3u8 playlists (saved as a rewritten playlist plus a segment
  /// directory) and direct media files of any container the player can
  /// demux. Playlist vs file is probed from the response body, not the URL:
  /// sources hand out direct media with query strings or no extension, and
  /// manifests likewise.
  static Future<DownloadedMedia> downloadMedia(
    String link,
    File file, {
    CancelToken? rhttpToken,
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
  }) async {
    final network = locate<NetworkService>();
    final stream = await network.client.getStream(
      link,
      cancelToken: rhttpToken,
      onReceiveProgress: _toRhttpProgress(onReceiveProgress),
      headers: headers != null ? HttpHeaders.rawMap(headers) : null,
    );
    final target = _resolveEnding(file, stream);
    final probe = BytesBuilder();
    IOSink? sink;
    var playlist = false;
    try {
      await for (final chunk in stream.body) {
        if (playlist) continue;
        if (sink != null) {
          sink.add(chunk);
          continue;
        }
        probe.add(chunk);
        if (probe.length < _mediaProbeLength) continue;
        if (looksLikeM3u8(probe.toBytes())) {
          // Manifests are small; drain the rest before refetching.
          playlist = true;
          continue;
        }
        sink = await _openMediaSink(target, probe);
      }
      if (!playlist && sink == null) {
        // Body ended within the probe window; decide on what arrived.
        playlist = looksLikeM3u8(probe.toBytes());
      }
      if (playlist) {
        return await _downloadPlaylist(
          link,
          target,
          headers: headers,
          rhttpToken: rhttpToken,
          onReceiveProgress: onReceiveProgress,
        );
      }
      sink ??= await _openMediaSink(target, probe);
      return DownloadedMedia(target, false);
    } finally {
      await sink?.close();
    }
  }

  /// Bytes probed before deciding manifest vs direct file; long enough for
  /// the #EXTM3U tag plus a BOM or leading whitespace.
  static const _mediaProbeLength = 512;

  static bool looksLikeM3u8(Uint8List bytes) {
    // Skip decoding binary content; only a BOM or '#' can start a manifest.
    if (bytes.isEmpty || (bytes[0] != 0xEF && bytes[0] != 0x23)) {
      return false;
    }
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return text.startsWith('#EXTM3U');
  }

  static Future<IOSink> _openMediaSink(File file, BytesBuilder probe) async {
    await file.create(recursive: true);
    final sink = file.openWrite();
    sink.add(probe.takeBytes());
    return sink;
  }

  static Future<DownloadedMedia> _downloadPlaylist(
    String link,
    File file, {
    CancelToken? rhttpToken,
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
  }) async {
    // Name the rewritten playlist explicitly: source URLs often carry no
    // or a misleading extension for manifests.
    final playlist = file.parent.getFile(
      '${file.filenameWithoutExtension}.m3u8',
    );
    final downloaded = await downloadm3u8(
      link,
      playlist,
      headers: headers,
      rhttpToken: rhttpToken,
      onReceiveProgress: onReceiveProgress,
    );
    return DownloadedMedia(downloaded, true);
  }

  static Future<File> downloadm3u8(
    String link,
    File file, {
    CancelToken? rhttpToken,
    Map<String, String>? headers,
    void Function(double)? onReceiveProgress,
  }) async {
    final dir = file.parent;
    final contentdir = dir.sub(file.filenameWithoutExtension);
    try {
      final network = locate<NetworkService>();
      final res = await network.client.get(
        link,
        headers: headers != null ? HttpHeaders.rawMap(headers) : null,
        cancelToken: rhttpToken,
      );
      final m3u8 = res.body.split('\n');
      // trim() also strips a BOM; callers may reach a manifest through a
      // URL with no .m3u8/.m3u ending.
      if (m3u8[0].trim() != '#EXTM3U') {
        throw Exception('Invalid m3u8 file $link');
      }

      if (!await contentdir.exists()) {
        await contentdir.create(recursive: true);
      }

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
              formatRelativeURI(artefactLink, link),
              contentdir.getFile('artefact$part'),
              headers: headers,
              onReceiveProgress: onReceiveProgress != null
                  ? (progress) => onReceiveProgress(
                      (progress + index) / playlist.length.toDouble(),
                    )
                  : null,
            );
            part++;
            e = e.replaceAll(artefactLink, res.relativePath(dir));
          } else {
            final res = await streamToFile(
              formatRelativeURI(artefactLink, link),
              contentdir.getFile('artefact$part'),
              headers: headers,
              onReceiveProgress: onReceiveProgress != null
                  ? (progress) => onReceiveProgress(
                      (progress + index) / playlist.length.toDouble(),
                    )
                  : null,
            );
            part++;
            e = e.replaceAll(artefactLink, res.relativePath(dir));
          }
        }
        newplaylist.add(e);
      }
      await file.writeAsString('#EXTM3U\n${newplaylist.join('\n')}');
    } catch (e, stack) {
      logger.e('Failed to download m3u8', error: e, stackTrace: stack);
      if (await file.exists()) {
        await file.delete();
      }
      if (await contentdir.exists()) {
        await contentdir.delete(recursive: true);
      }
      rethrow;
    }
    return file;
  }

  static Function(int, int)? _toRhttpProgress(
    void Function(double)? onReceiveProgress,
  ) {
    if (onReceiveProgress == null) return null;
    return (count, total) {
      if (total < 0) return;
      onReceiveProgress(count / total);
    };
  }

  static String formatRelativeURI(String link, String location) {
    if (!['http://', 'https://'].any((e) => link.startsWith(e))) {
      return '${location.substring(0, location.lastIndexOf('/'))}/$link';
    }
    return link;
  }

  static String? _parseFileending(String url) {
    var link = url;
    final params = link.lastIndexOf('?');
    if (params != -1) {
      link = link.substring(0, params);
    }
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

  static String? _parseFilename(String url) {
    var link = url;
    final params = link.lastIndexOf('?');
    if (params != -1) {
      link = link.substring(0, params);
    }
    var dotIndex = link.lastIndexOf('.');
    if (dotIndex == -1) {
      dotIndex = link.length;
    }
    final lastSlash = link.lastIndexOf('/');
    if (lastSlash == -1) {
      return link.substring(0, dotIndex);
    }
    return link.substring(lastSlash + 1, dotIndex);
  }
}

class DownloadedMedia {
  final File file;

  /// True when [file] is a rewritten m3u8 playlist whose segments live
  /// next to it; false for a single direct media file.
  final bool isPlaylist;

  const DownloadedMedia(this.file, this.isPlaylist);
}
