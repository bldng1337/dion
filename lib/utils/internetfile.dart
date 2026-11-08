import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
          await sink.flush();
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
      // trim() also strips a BOM; callers may reach a manifest through a
      // URL with no .m3u8/.m3u ending.
      final m3u8 = const LineSplitter().convert(res.body);
      if (m3u8.isEmpty || m3u8[0].trim() != '#EXTM3U') {
        throw Exception('Invalid m3u8 file $link');
      }

      if (!await contentdir.exists()) {
        await contentdir.create(recursive: true);
      }

      final playlist = selectBestVariant(m3u8.sublist(1));
      var part = 0;
      final urimatcher = RegExp('URI="([^"]*)"');
      final newplaylist = <String>[];
      var followsStreamInf = false;
      for (final (index, line) in playlist.indexed) {
        onReceiveProgress?.call(index / playlist.length.toDouble());
        var e = line.trim();
        if (e.isEmpty) continue;
        final isTag = e.startsWith('#');
        final isPlaylistUri = isTag
            ? e.startsWith('#EXT-X-MEDIA:')
            : followsStreamInf;
        if (isTag) {
          if (e.startsWith('#EXT-X-STREAM-INF')) followsStreamInf = true;
        } else {
          followsStreamInf = false;
        }
        final links = isTag
            ? urimatcher
                  .allMatches(e)
                  .map((e) => e.group(1)!.trim())
                  .where((e) => e.isNotEmpty)
            : [e];
        final partProgress = onReceiveProgress == null
            ? null
            : (double progress) => onReceiveProgress(
                (progress + index) / playlist.length.toDouble(),
              );
        for (final artefactLink in links) {
          final resolved = formatRelativeURI(artefactLink, link);
          // data: keys and DRM key schemes have nothing to fetch.
          if (!resolved.startsWith('http://') &&
              !resolved.startsWith('https://')) {
            continue;
          }
          final File res;
          if (isPlaylistUri || _pointsToPlaylist(artefactLink)) {
            res = await downloadm3u8(
              resolved,
              contentdir.getFile('artefact$part.m3u8'),
              headers: headers,
              rhttpToken: rhttpToken,
              onReceiveProgress: partProgress,
            );
          } else {
            res = await streamToFile(
              resolved,
              fromURI(resolved, contentdir, filename: 'artefact$part'),
              headers: headers,
              rhttpToken: rhttpToken,
              onReceiveProgress: partProgress,
              resolveEnding: true,
            );
          }
          part++;
          e = e.replaceAll(
            artefactLink,
            res.relativePath(dir).replaceAll(r'\', '/'),
          );
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

  static bool _pointsToPlaylist(String link) {
    final path = (Uri.tryParse(link)?.path ?? link).toLowerCase();
    return path.endsWith('.m3u8') || path.endsWith('.m3u');
  }

  static final _bandwidth = RegExp(r'[:,]BANDWIDTH=(\d+)');
  static final _renditionGroups = RegExp(
    '(?:AUDIO|VIDEO|SUBTITLES)="([^"]*)"',
  );
  static final _groupId = RegExp('GROUP-ID="([^"]*)"');

  @visibleForTesting
  static List<String> selectBestVariant(List<String> lines) {
    final variants = <(int, int, int)>[]; // (bandwidth, tag line, uri line)
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].trim().startsWith('#EXT-X-STREAM-INF')) continue;
      final uriLine = lines.indexWhere(
        (l) => l.trim().isNotEmpty && !l.trim().startsWith('#'),
        i + 1,
      );
      if (uriLine == -1) continue;
      final bandwidth = int.parse(
        _bandwidth.firstMatch(lines[i])?.group(1) ?? '0',
      );
      variants.add((bandwidth, i, uriLine));
    }
    if (variants.isEmpty) return lines;
    final best = variants.reduce((a, b) => b.$1 > a.$1 ? b : a);
    final dropped = {
      for (final variant in variants)
        if (variant != best) ...[variant.$2, variant.$3],
    };
    final groups = _renditionGroups
        .allMatches(lines[best.$2])
        .map((m) => m.group(1))
        .toSet();
    return [
      for (final (index, line) in lines.indexed)
        if (!dropped.contains(index) &&
            !line.trim().startsWith('#EXT-X-I-FRAME-STREAM-INF') &&
            (!line.trim().startsWith('#EXT-X-MEDIA:') ||
                groups.contains(_groupId.firstMatch(line)?.group(1))))
          line,
    ];
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

  static String formatRelativeURI(String link, String location) =>
      Uri.parse(location).resolve(link).toString();

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
