import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';

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
      return AlertDialog(
        title: const Text('Error Installing Update'),
        content: ErrorDisplay(e: error!),
        actions: [
          DionTextbutton(
            child: const Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }
    if (!loading) {
      return AlertDialog(
        title: Text('Version ${widget.update.version} is available!',
            style: context.titleLarge),
        content: Text(
          widget.update.body,
          style: context.bodyMedium,
        ),
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
    return AlertDialog(
      title: const Text('Installing Update...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          LinearProgressIndicator(
            value: progress,
          ),
        ],
      ),
    );
  }
}
