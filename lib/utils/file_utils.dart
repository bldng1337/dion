import 'dart:io';

import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rdion_runtime/rdion_runtime.dart';

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
        '${p.join(parent.path, p.basenameWithoutExtension(absolute.path))}$name');
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

abstract class DirectoryProvider {
  const DirectoryProvider();
  Directory get basepath;
  Directory get extensionpath;
  Directory get databasepath;

  static Future<void> ensureInitialized() async {
    final basepath = await getBasePath();
    logger.i('Initializing DirectoryProvider to $basepath');
    final extensionpath =
        await basepath.sub('extension').create(recursive: true);
    final databasepath = await basepath.sub('database').create(recursive: true);
    register<DirectoryProvider>(DirectoryProviderImpl(basepath, extensionpath, databasepath));
  }
}

class DirectoryProviderImpl extends DirectoryProvider {
  @override
  final Directory basepath;
  @override
  final Directory extensionpath;
  @override
  final Directory databasepath;

  const DirectoryProviderImpl(
      this.basepath, this.extensionpath, this.databasepath);
}
