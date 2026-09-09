import 'dart:io';

import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
import 'package:dionysos/utils/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/v4.dart';

/// Resolves a source link to a local file. Remote sources are streamed into
/// the temporary directory so readers can open them lazily from disk (e.g.
/// PDFium random access) instead of buffering the whole file in memory.
Future<File> resolveSourceFile(Link link) async {
  if (isFileUrl(link.url)) {
    return fileFromUrl(link.url);
  }
  final dir = await getTemporaryDirectory();
  final file = InternetFile.fromURI(
    link.url,
    dir,
    filename: 'source-${const UuidV4().generate()}',
  );
  return InternetFile.streamToFile(link.url, file, headers: link.header);
}

/// Deletes a file created by [resolveSourceFile]. Failures (e.g. the platform
/// viewer still holding the file open) are ignored; the OS cleans up the
/// temporary directory eventually.
Future<void> deleteResolvedSource(Link link, File file) async {
  if (isFileUrl(link.url)) return;
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e) {
    logger.d('Failed to delete temporary source file: $e');
  }
}
