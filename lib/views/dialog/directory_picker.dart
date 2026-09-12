import 'dart:async';
import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/android_storage.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show ToastKind;

Future<String?> pickDirectoryPath(
  BuildContext context, {
  bool write = false,
  String? initialDirectory,
}) async {
  if (!Platform.isAndroid) {
    return await getDirectoryPath(initialDirectory: initialDirectory);
  }
  if (!await _ensureAndroidStorageAccess(context, write: write)) return null;
  if (!context.mounted) return null;
  try {
    return await getDirectoryPath(initialDirectory: initialDirectory);
  } on PlatformException {
    showToast(
      'This location cannot be used. Pick a folder on device storage.',
      ToastKind.warning,
    );
    return null;
  }
}

Future<bool> _ensureAndroidStorageAccess(
  BuildContext context, {
  required bool write,
}) async {
  if (await AndroidStorage.hasStorageAccess(write: write)) return true;
  final sdkInt = await AndroidStorage.sdkInt;
  if (!context.mounted) return false;
  final wantsGrant = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DionAlertDialog(
      title: const Text('Storage Access Required'),
      content: Text(
        sdkInt >= 30
            ? 'To pick a directory, dion needs access to your device storage. '
                  'Enable "All files access" for dion on the screen that opens next.'
            : 'To pick a directory, dion needs permission to access your '
                  'device storage.',
        style: dialogContext.bodyMedium,
      ),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        DionTextbutton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (wantsGrant != true) return false;
  if (sdkInt >= 30) {
    if (!await AndroidStorage.openAllFilesAccessSettings()) return false;
    await _waitForAppReturn();
    return await AndroidStorage.hasStorageAccess(write: write);
  }
  return await AndroidStorage.requestStoragePermission(write: write);
}

Future<void> _waitForAppReturn() {
  final returned = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!returned.isCompleted) returned.complete();
    },
  );
  return returned.future
      .timeout(const Duration(minutes: 15))
      .catchError((_) {})
      .whenComplete(listener.dispose);
}
