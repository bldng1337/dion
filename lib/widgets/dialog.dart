import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

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
