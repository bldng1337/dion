import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

extension FileUtils on File {
  String get filename {
    return p.basename(path);
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
