import 'dart:io';

import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:path_provider/path_provider.dart';

class DirectoryProvider {
  final Directory basepath;
  final Directory extensionpath;
  final Directory databasepath;
  final Directory temppath;
  final Directory downloadspath;

  const DirectoryProvider({
    required this.basepath,
    required this.extensionpath,
    required this.databasepath,
    required this.temppath,
    required this.downloadspath,
  });

  static Future<void> ensureInitialized() async {
    final basepath = await getBasePath();
    logger.i('Initializing DirectoryProvider to $basepath');

    final temppath = (await getTemporaryDirectory()).sub('dion');
    try {
      if (await temppath.exists()) {
        await temppath.delete(recursive: true);
      }
      await temppath.create(recursive: true);
    } catch (e, stack) {
      logger.e(
        'Failed to recreate temp directory',
        error: e,
        stackTrace: stack,
      );
    }

    register<DirectoryProvider>(
      DirectoryProvider(
        basepath: basepath,
        temppath: temppath,
        extensionpath: await basepath.sub('extension').create(recursive: true),
        databasepath: await basepath.sub('database').create(recursive: true),
        downloadspath: await basepath.sub('downloads').create(recursive: true),
      ),
    );
  }

  Future<void> clear() async {
    await basepath.delete(recursive: true);
    await extensionpath.delete(recursive: true);
    await databasepath.delete(recursive: true);
    await temppath.delete(recursive: true);
  }
}
