import 'dart:io';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/android_storage.dart';
import 'package:dionysos/views/dialog/directory_picker.dart';
import 'package:flutter/widgets.dart';

Future<bool> ensureBackupAccess(BuildContext context) async {
  if (!Platform.isAndroid) return true;
  final custom = settings.backup.path.value != null;
  if (!custom && await AndroidStorage.sdkInt >= 30) return true;
  if (!context.mounted) return false;
  return ensureAndroidStorageAccess(
    context,
    write: true,
    purpose: 'save backups',
  );
}
