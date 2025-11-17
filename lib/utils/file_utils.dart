import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

extension FileUtils on File {
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
  if (kDebugMode) {
  return (await getApplicationDocumentsDirectory())
      .sub('diondev')
      .create(recursive: true);
  }
  return (await getApplicationDocumentsDirectory())
      .sub('dion')
      .create(recursive: true);
}
