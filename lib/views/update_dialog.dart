import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/backup.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/views/dialog/backup_access.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatefulWidget {
  final Update update;
  const UpdateDialog({super.key, required this.update});

  @override
  _UpdateDialogState createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool loading = false;
  double? progress = 0;
  String message = '';
  Object? error;
  Object? backupError;

  Future<void> _install({bool backup = true}) async {
    setState(() {
      loading = true;
      backupError = null;
    });
    if (backup && settings.backup.beforeUpdate.value) {
      if (!await _backup()) return;
    }
    try {
      await downloadUpdate(
        widget.update,
        onReceiveProgress: (progress, phase) {
          safeSetState(() {
            this.progress = progress;
            message = phase;
          });
        },
      );
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
      error = e;
    }
    safeSetState(() {
      loading = false;
    });
  }

  Future<bool> _backup() async {
    setState(() {
      progress = null;
      message = 'Backing up your library';
    });
    try {
      if (!await ensureBackupAccess(context)) {
        throw StateError('Storage access was not granted');
      }
      final version = await getVersion();
      await writeBackup(label: 'pre-update-v${version.canonicalizedVersion}');
      return true;
    } catch (e, stack) {
      logger.e('Backup before update failed', error: e, stackTrace: stack);
      safeSetState(() {
        backupError = e;
        loading = false;
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (backupError != null) {
      return DionAlertDialog(
        title: const Text('Backup Failed'),
        content: Text(
          'Your library could not be backed up before the update '
          '(${errorText(backupError)}). Install anyway?',
          style: context.bodyMedium,
        ),
        actions: [
          DionTextbutton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          DionTextbutton(
            child: const Text('Install anyway'),
            onPressed: () => _install(backup: false),
          ),
        ],
      );
    }
    if (error != null) {
      return DionAlertDialog(
        title: const Text('Error Installing Update'),
        content: ErrorDisplay(e: error),
        actions: [
          DionTextbutton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          DionTextbutton(
            child: const Text('Go to download page'),
            onPressed: () async {
              await launchUrl(Uri.parse(widget.update.link));
            },
          ),
        ],
      );
    }
    if (!loading) {
      final commit = widget.update.commit;
      return DionAlertDialog(
        title: Text(
          commit == null
              ? 'Version ${widget.update.version} is available!'
              : 'Nightly build $commit is available!',
          style: context.titleLarge,
        ),
        content: Text(widget.update.body, style: context.bodyMedium),
        actions: [
          DionTextbutton(onPressed: _install, child: const Text('Install')),
          DionTextbutton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    return DionAlertDialog(
      title: const Text('Installing Update...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          DionProgressBar(value: progress, type: DionProgressType.linear),
        ],
      ),
    );
  }
}
