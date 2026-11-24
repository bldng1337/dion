import 'dart:io';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_overrides.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/image_store.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' show Icons, showDialog;
import 'package:flutter/widgets.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

Future<bool> showEntryEditor(BuildContext context, EntrySaved entry) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _EntryEditorDialog(entry: entry),
  );
  return changed ?? false;
}

Future<bool> saveEntryOverrides(
  EntrySaved entry,
  EntryOverrides overrides,
) async {
  final previous = entry.overrides;
  final persisted = overrides
      .withCover(await _persistLink(overrides.cover))
      .withPoster(await _persistLink(overrides.poster));
  if (persisted == previous) return false;
  entry.overrides = persisted;
  await entry.save();
  final store = locate<ImageStoreService>();
  for (final (old, now) in [
    (previous.cover, persisted.cover),
    (previous.poster, persisted.poster),
  ]) {
    if (old?.url != now?.url) await store.deleteCustomImage(old?.url);
  }
  return true;
}

enum EntryImageSlot {
  cover('Cover'),
  banner('Banner');

  final String label;
  const EntryImageSlot(this.label);
}

Future<bool> setEntryImage(
  EntrySaved entry,
  EntryImageSlot slot,
  rust.Link image,
) {
  final source = switch (slot) {
    EntryImageSlot.cover => entry.entry.cover,
    EntryImageSlot.banner => entry.entry.poster,
  };
  final link = image.url == source?.url ? null : image;
  return saveEntryOverrides(entry, switch (slot) {
    EntryImageSlot.cover => entry.overrides.withCover(link),
    EntryImageSlot.banner => entry.overrides.withPoster(link),
  });
}

Future<rust.Link?> _persistLink(rust.Link? link) async {
  if (link == null || !isFileUrl(link.url)) return link;
  final store = locate<ImageStoreService>();
  if (store.isCustomImage(link.url)) return link;
  final url = await store.importCustomImage(fileFromUrl(link.url));
  return rust.Link(url: url);
}

class _EntryEditorDialog extends StatefulWidget {
  final EntrySaved entry;

  const _EntryEditorDialog({required this.entry});

  @override
  State<_EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<_EntryEditorDialog> {
  /// The values the entry shows without any user edit.
  rust.EntryDetailed get _source => widget.entry.entry;

  late final _title = TextEditingController(text: widget.entry.title);
  late final _author = TextEditingController(
    text: _joinList(widget.entry.author),
  );
  late final _genres = TextEditingController(
    text: _joinList(widget.entry.genres),
  );
  late final _description = TextEditingController(
    text: widget.entry.description,
  );
  late final _cover = TextEditingController(
    text: widget.entry.cover?.url ?? '',
  );
  late final _poster = TextEditingController(
    text: widget.entry.poster?.url ?? '',
  );

  bool _saving = false;

  List<TextEditingController> get _controllers => [
    _title,
    _author,
    _genres,
    _description,
    _cover,
    _poster,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _joinList(List<String>? values) => values?.join(', ') ?? '';

  static List<String> _splitList(String text) => [
    for (final part in text.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  static bool _sameList(List<String> a, List<String>? b) {
    final other = b ?? const <String>[];
    if (a.length != other.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != other[i]) return false;
    }
    return true;
  }

  List<String>? _listOverride(String text, List<String>? source) {
    final values = _splitList(text);
    return _sameList(values, source) ? null : values;
  }

  rust.Link? _linkOverride(String text, rust.Link? source) {
    final url = text.trim();
    if (url.isEmpty || url == source?.url) return null;
    return rust.Link(url: url);
  }

  EntryOverrides _buildOverrides() {
    final title = _title.text.trim();
    return EntryOverrides(
      title: title.isEmpty || title == _source.titles.first ? null : title,
      author: _listOverride(_author.text, _source.author),
      genres: _listOverride(_genres.text, _source.genres),
      description: _description.text.trim() == _source.description.trim()
          ? null
          : _description.text.trim(),
      cover: _linkOverride(_cover.text, _source.cover),
      poster: _linkOverride(_poster.text, _source.poster),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final changed = await saveEntryOverrides(
        widget.entry,
        _buildOverrides(),
      );
      if (mounted) Navigator.of(context).pop(changed);
    } catch (e, stack) {
      logger.e('Failed to save entry edits', error: e, stackTrace: stack);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetAll() {
    _title.text = _source.titles.first;
    _author.text = _joinList(_source.author);
    _genres.text = _joinList(_source.genres);
    _description.text = _source.description;
    _cover.text = _source.cover?.url ?? '';
    _poster.text = _source.poster?.url ?? '';
  }

  Future<void> _pickImage(TextEditingController controller) async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'],
      uniformTypeIdentifiers: <String>['public.image'],
      mimeTypes: <String>['image/*'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      controller.text = File(file.path).fileURL;
    } catch (e, stack) {
      logger.e('Failed to open image picker', error: e, stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(_controllers),
      builder: (context, _) {
        final hasEdits = !_buildOverrides().isEmpty;
        return DionAlertDialog(
          title: const Text('Edit Entry'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TextField(
                    label: 'Title',
                    controller: _title,
                    source: _source.titles.first,
                  ),
                  _TextField(
                    label: 'Authors',
                    hint: 'Separate with commas',
                    controller: _author,
                    source: _joinList(_source.author),
                  ),
                  _TextField(
                    label: 'Tags',
                    hint: 'Separate with commas',
                    controller: _genres,
                    source: _joinList(_source.genres),
                  ),
                  _TextField(
                    label: 'Description',
                    controller: _description,
                    source: _source.description,
                    minLines: 3,
                    maxLines: 8,
                  ),
                  _ImageField(
                    label: 'Cover',
                    hint: 'Shown in the library and on the detail page',
                    controller: _cover,
                    source: _source.cover,
                    onPick: () => _pickImage(_cover),
                  ),
                  _ImageField(
                    label: 'Banner',
                    hint: 'Header background; falls back to the cover',
                    controller: _poster,
                    source: _source.poster,
                    onPick: () => _pickImage(_poster),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            DionTextbutton(
              type: ButtonType.ghost,
              onPressed: _saving || !hasEdits ? null : _resetAll,
              child: const Text('Reset All'),
            ),
            DionTextbutton(
              type: ButtonType.ghost,
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            DionTextbutton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool edited;
  final VoidCallback onReset;

  const _FieldLabel({
    required this.label,
    required this.edited,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(label, style: DionTypography.titleSmall(context.textPrimary)),
          if (edited) ...[
            const SizedBox(width: DionSpacing.sm),
            Text(
              'EDITED',
              style: DionTypography.sectionHeader(context.textTertiary),
            ),
            const Spacer(),
            DionIconbutton(
              tooltip: 'Reset $label to source',
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String source;
  final int? minLines;
  final int maxLines;

  const _TextField({
    required this.label,
    required this.controller,
    required this.source,
    this.hint,
    this.minLines,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label: label,
          edited: controller.text.trim() != source.trim(),
          onReset: () => controller.text = source,
        ),
        DionTextbox(
          controller: controller,
          hintText: hint,
          minLines: minLines,
          maxLines: maxLines,
        ),
        const SizedBox(height: DionSpacing.md),
      ],
    );
  }
}

class _ImageField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final rust.Link? source;
  final VoidCallback onPick;

  const _ImageField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.source,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final url = controller.text.trim();
    final sourceUrl = source?.url ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label: label,
          edited: url.isNotEmpty && url != sourceUrl,
          onReset: () => controller.text = sourceUrl,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 76,
              decoration: BoxDecoration(
                color: context.surfaceMuted,
                borderRadius: DionRadius.small,
              ),
              clipBehavior: Clip.antiAlias,
              child: url.isEmpty
                  ? Icon(Icons.image_outlined, color: context.textTertiary)
                  : DionImage(
                      key: ValueKey(url),
                      imageUrl: url,
                      httpHeaders: url == sourceUrl ? source?.header : null,
                      boxFit: BoxFit.cover,
                      errorWidget: Icon(
                        Icons.broken_image_outlined,
                        color: context.textTertiary,
                      ),
                    ),
            ),
            const SizedBox(width: DionSpacing.md),
            Expanded(
              child: DionTextbox(
                controller: controller,
                hintText: 'Image URL',
                maxLines: 1,
              ),
            ),
            DionIconbutton(
              tooltip: 'Choose file',
              onPressed: onPick,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
          ],
        ),
        Text(
          hint,
          style: DionTypography.bodySmall(context.textTertiary),
        ).paddingOnly(top: DionSpacing.xs),
        const SizedBox(height: DionSpacing.md),
      ],
    );
  }
}
