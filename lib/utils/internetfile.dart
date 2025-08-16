import 'dart:io';

import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart';
import 'package:uuid/v4.dart';

class InternetFile {
  static File fromURI(String link, Directory dir, {String? filename}) {
    final fileending = _parseFileending(link) ?? '';
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
  }) async {
    final network = locate<NetworkService>();
    final stream = await network.client.getStream(
      link,
      cancelToken: rhttpToken,
      onReceiveProgress: _toRhttpProgress(onReceiveProgress),
      headers: headers != null ? HttpHeaders.rawMap(headers) : null,
    );
    await file.streamToFile(stream.body);
    return file;
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
      if (m3u8[0] != '#EXTM3U') {
        throw Exception('Invalid m3u8 file');
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
      await file.delete();
      await contentdir.delete(recursive: true);
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
