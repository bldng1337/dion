import 'package:dionysos/data/text_replacement.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:flutter/material.dart';

Future<TextReplacement?> showReplacementEditor(
  BuildContext context, {
  String? find,
  String? replaceWith,
  bool autofocusReplacement = false,
}) {
  return showDialog<TextReplacement>(
    context: context,
    builder: (dialogContext) => _ReplacementEditorDialog(
      find: find,
      replaceWith: replaceWith,
      autofocusReplacement: autofocusReplacement,
    ),
  );
}

class _ReplacementEditorDialog extends StatefulWidget {
  final String? find;
  final String? replaceWith;
  final bool autofocusReplacement;

  const _ReplacementEditorDialog({
    this.find,
    this.replaceWith,
    this.autofocusReplacement = false,
  });

  @override
  State<_ReplacementEditorDialog> createState() =>
      _ReplacementEditorDialogState();
}

class _ReplacementEditorDialogState extends State<_ReplacementEditorDialog> {
  late final _find = TextEditingController(text: widget.find ?? '');
  late final _replaceWith = TextEditingController(
    text: widget.replaceWith ?? '',
  );

  @override
  void dispose() {
    _find.dispose();
    _replaceWith.dispose();
    super.dispose();
  }

  void _submit() {
    final find = _find.text;
    if (find.isEmpty) return;
    Navigator.of(context)
        .pop(TextReplacement(find: find, replaceWith: _replaceWith.text));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_find, _replaceWith]),
      builder: (context, _) => DionAlertDialog(
        title: const Text('Text Replacement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find', style: DionTypography.titleSmall(context.textPrimary)),
            DionTextbox(
              controller: _find,
              autofocus: !widget.autofocusReplacement,
              maxLines: 1,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: DionSpacing.md),
            Text(
              'Replace with',
              style: DionTypography.titleSmall(context.textPrimary),
            ),
            DionTextbox(
              controller: _replaceWith,
              autofocus: widget.autofocusReplacement,
              maxLines: 1,
              onSubmitted: (_) => _submit(),
              hintText: 'Leave empty to remove the text',
            ),
          ],
        ),
        actions: [
          DionTextbutton(
            type: ButtonType.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          DionTextbutton(
            onPressed: _find.text.isEmpty ? null : _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
