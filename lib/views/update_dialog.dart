import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/update.dart';
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
  double progress = 0;
  String message = '';
  Object? error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
      return DionAlertDialog(
        title: Text(
          'Version ${widget.update.version} is available!',
          style: context.titleLarge,
        ),
        content: Text(widget.update.body, style: context.bodyMedium),
        actions: [
          DionTextbutton(
            onPressed: () async {
              setState(() {
                loading = true;
              });
              try {
                await downloadUpdate(
                  widget.update,
                  onReceiveProgress: (progress, phase) {
                    setState(() {
                      this.progress = progress ?? -1;
                      message = phase;
                    });
                  },
                );
              } catch (e, stack) {
                logger.e(e, stackTrace: stack);
                error = e;
              }
              if (!mounted) {
                return;
              }
              setState(() {
                loading = false;
              });
            },
            child: const Text('Install'),
          ),
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
