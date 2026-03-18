import 'dart:io';
import 'dart:math';

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  final i = (log(bytes) / log(1024)).floor();
  final value = bytes / pow(1024, i);
  return '${value.toStringAsFixed(value>=10?0:decimals)} ${suffixes[i]}';
}

Future<int> getDirectorySize(Directory dir) async {
  if (!await dir.exists()) {
    return 0;
  }

  int totalSize = 0;

  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalSize += stat.size;
        } catch (e) {
          continue;
        }
      }
    }
  } catch (e) {
    return 0;
  }

  return totalSize;
}
