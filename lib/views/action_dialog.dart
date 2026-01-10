import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/widgets.dart';

class ActionDialog extends StatelessWidget {
  final Action_Popup popup;
  final Extension extension;

  const ActionDialog({super.key, required this.popup, required this.extension});

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Text(popup.title, style: context.titleLarge),
      content: CustomUIWidget.fromUI(ui: popup.content, extension: extension),
      actions: [
        DionTextbutton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ...popup.actions.map(
          (action) => DionTextbutton(
            child: Text(action.label),
            onPressed: () async {
              await extension.runAction(action.onclick);
            },
          ),
        ),
      ],
    );
  }
}
