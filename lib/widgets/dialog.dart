import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await material.showDialog<bool>(
    context: context,
    builder: (context) => DionAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        DionTextbutton(
          color: destructive ? DionColors.error : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class DionAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  const DionAlertDialog({super.key, this.title, this.content, this.actions});

  @override
  Widget build(BuildContext context) {
    return material.AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      title: title,
      content: content,
      actions: actions,
    );
  }
}

class DionDialog extends StatelessWidget {
  final Widget? child;
  const DionDialog({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return material.Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(3)),
      ),
      child: child,
    );
  }
}
