import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local file locations are stored as `file://<path>` — a plain path appended
/// to the scheme, not an RFC 8089 file URI: `Uri.parse` would read a Windows
/// drive as the URI host and resolve it to an unreachable UNC path
/// (`\\c\Users\...`). The image widgets and the runtime strip the prefix the
/// same way.
const String _fileUrlPrefix = 'file://';

bool isFileUrl(String url) => url.startsWith(_fileUrlPrefix);

File fileFromUrl(String url) {
  final rest = url.substring(_fileUrlPrefix.length);
  if (rest.startsWith('/') || !rest.contains(':')) {
    // Well-formed URI ('file:///...' or 'file://host/...'); File.fromUri also
    // percent-decodes. The legacy format below never starts with '/' on POSIX
    // paths, so the two remain distinguishable.
    return File.fromUri(Uri.parse(url));
  }
  return File(rest);
}

extension FileUtils on File {
  // Legacy wire format shared with the runtime; parse it with fileFromUrl.
  String get fileURL {
    return 'file://$path';
  }

  String get filename {
    return p.basename(path);
  }

  String get filenameWithoutExtension {
    return p.basenameWithoutExtension(path);
  }

  String get extension {
    return p.extension(path, 99);
  }

  File silbling(String name) {
    return File(p.join(parent.path, name));
  }

  File twin(String name) {
    return File(
      '${p.join(parent.path, p.basenameWithoutExtension(absolute.path))}$name',
    );
  }

  Future<void> streamToFile(Stream<Uint8List> stream) async {
    final file = await create(recursive: true);
    final sink = file.openWrite();
    try {
      await for (final chunk in stream) {
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }

  String relativePath(Directory dir) {
    return p.relative(absolute.path, from: dir.absolute.path);
  }
}

extension DirUtils on Directory {
  Directory sub(String path) {
    return Directory(p.join(absolute.path, path));
  }

  String get name {
    return p.basename(path);
  }

  File getFile(String filename) {
    return File(p.join(path, filename));
  }
}

Future<Directory> getPath(String name, {bool create = true}) async {
  if (create) {
    return (await getBasePath()).sub(name)..create(recursive: true);
  }
  return (await getBasePath()).sub(name);
}

Future<Directory> getBasePath() async {
  if (kDebugMode || kProfileMode) {
    return (await getApplicationDocumentsDirectory())
        .sub('diondev')
        .create(recursive: true);
  }
  return (await getApplicationDocumentsDirectory())
      .sub('dion')
      .create(recursive: true);
}

String sanitizePathSegment(String segment) {
  return segment
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>| }{}\-,]'), '')
      .replaceAll(RegExp('[_]{2,}'), '_');
}
