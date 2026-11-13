import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:flutter/material.dart' show Icons, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class TailscaleAuthKeyDialog extends StatefulWidget {
  const TailscaleAuthKeyDialog({super.key});

  @override
  State<TailscaleAuthKeyDialog> createState() => _TailscaleAuthKeyDialogState();
}

class _TailscaleAuthKeyDialogState extends State<TailscaleAuthKeyDialog>
    with StateDisposeScopeMixin {
  late final TextEditingController _controller = TextEditingController()
    ..disposedBy(scope);

  void _submit() {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    Navigator.pop(context, key);
  }

  @override
  Widget build(BuildContext context) {
    return DionAlertDialog(
      title: Row(
        children: [
          Icon(Icons.vpn_key, color: context.theme.colorScheme.primary),
          const SizedBox(width: DionSpacing.sm),
          Text('Tailscale Auth Key', style: context.titleLarge),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste an auth key from the admin console of your tailnet to '
              'add this device without logging in through the browser.',
              style: context.bodyMedium,
            ),
            const SizedBox(height: DionSpacing.lg),
            DionTextbox(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              hintText: 'tskey-auth-…',
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        DionTextbutton(
          type: ButtonType.ghost,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        DionTextbutton(onPressed: _submit, child: const Text('Connect')),
      ],
    );
  }
}
