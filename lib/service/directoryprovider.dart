import 'dart:io';

import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';

abstract class DirectoryProvider {
  const DirectoryProvider();
  Directory get basepath;
  Directory get extensionpath;
  Directory get databasepath;
  Directory get temppath;

  static Future<void> ensureInitialized() async {
    final basepath = await getBasePath();
    logger.i('Initializing DirectoryProvider to $basepath');
    final extensionpath =
        await basepath.sub('extension').create(recursive: true);
    final databasepath = await basepath.sub('database').create(recursive: true);
    final temppath = await basepath.sub('temp').create(recursive: true);
    await temppath.delete(recursive: true);
    await temppath.create(recursive: true);
    register<DirectoryProvider>(
      DirectoryProviderImpl(basepath, extensionpath, databasepath, temppath),
    );
  }

  Future<void> clear();
}

class DirectoryProviderImpl extends DirectoryProvider {
  @override
  final Directory basepath;
  @override
  final Directory extensionpath;
  @override
  final Directory databasepath;
  @override
  final Directory temppath;

  const DirectoryProviderImpl(
    this.basepath,
    this.extensionpath,
    this.databasepath,
    this.temppath,
  );

  @override
  Future<void> clear() async {
    await basepath.delete(recursive: true);
    await extensionpath.delete(recursive: true);
    await databasepath.delete(recursive: true);
    await temppath.delete(recursive: true);
  }
}
