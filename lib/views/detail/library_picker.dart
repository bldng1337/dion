import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart'
    hide
        Alignment,
        ButtonType,
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        StackFit,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/autoadd.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:flutter/material.dart'
    show Checkbox, CircularProgressIndicator, Colors, Icons, InkWell, Material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class LibraryPickerResult {
  final List<Category> categories;
  final Set<String> entryExtensionIds;
  final Set<String> sourceExtensionIds;

  const LibraryPickerResult(
    this.categories,
    this.entryExtensionIds,
    this.sourceExtensionIds,
  );
}

class LibrarySaveSheet extends StatefulWidget {
  final Rect anchor;
  final EntryDetailed entry;
  final VoidCallback onDismiss;
  final void Function(LibraryPickerResult result) onCommit;

  const LibrarySaveSheet({
    super.key,
    required this.anchor,
    required this.entry,
    required this.onDismiss,
    required this.onCommit,
  });

  @override
  State<LibrarySaveSheet> createState() => _LibrarySaveSheetState();
}

class _LibrarySaveSheetState extends State<LibrarySaveSheet> {
  static const _panelWidth = 340.0;

  bool _extensionsTab = true;
  late final Set<String> _entryExtensionIds;
  late final Set<String> _sourceExtensionIds;
  final Set<Category> _categories = {};
  late final Set<String> _autoIds;
  bool _dismissed = false;
  final _newCategoryController = TextEditingController();
  late Future<List<Category>> _categoriesFuture = locate<Database>()
      .getCategories();

  final _scopeNode = FocusScopeNode();

  bool get _isSaved => widget.entry is EntrySaved;

  @override
  void initState() {
    super.initState();
    final saved = widget.entry is EntrySaved
        ? widget.entry as EntrySaved
        : null;
    _entryExtensionIds =
        saved?.entryExtensions.map((e) => e.extensionId).toSet() ?? {};
    _sourceExtensionIds =
        saved?.sourceExtensions.map((e) => e.extensionId).toSet() ?? {};
    _categories.addAll(saved?.categories ?? const []);
    // Pre-tick auto-add rule matches as the defaults for unsaved entries.
    _autoIds = saved == null
        ? autoAddCandidatesFor(widget.entry).map((e) => e.id).toSet()
        : {};
    _entryExtensionIds.addAll(_autoIds);
    _sourceExtensionIds.addAll(_autoIds);
    // Pull focus into the sheet's scope once mounted so keyboard traversal
    // starts (and stays) inside it: FocusScope.autofocus alone is a no-op
    // when the enclosing scope already has a focused child (the page).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scopeNode.requestFocus();
      }
    });
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _newCategoryController.dispose();
    _scopeNode.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      return true;
    }
    return false;
  }

  /// Dismissal without the explicit save button cancels all changes.
  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  void _toggleId(Set<String> ids, String id) {
    setState(() {
      if (!ids.remove(id)) {
        ids.add(id);
      }
    });
  }

  List<Extension> _availableExtensions<T extends rust.ExtensionType>() {
    return locate<ExtensionService>()
        .getExtensions()
        .where(
          (ext) => ext.isenabled && ext.getExtensionTypeOrNull<T>() != null,
        )
        .toList();
  }

  Widget _buildExtensionRows(
    BuildContext context, {
    required List<Extension> available,
    required Set<String> attachedIds,
  }) {
    final attachedKnown = available
        .where((ext) => attachedIds.contains(ext.id))
        .toList();
    final unattached = available
        .where((ext) => !attachedIds.contains(ext.id))
        .toList();
    final unknownIds = attachedIds
        .where((id) => locate<ExtensionService>().tryGetExtension(id) == null)
        .toList();
    final hasRows =
        attachedKnown.isNotEmpty ||
        unattached.isNotEmpty ||
        unknownIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ext in attachedKnown)
          _buildExtensionRow(context, ext, attachedIds),
        for (final id in unknownIds)
          _buildUnknownExtensionRow(context, id, attachedIds),
        for (final ext in unattached)
          _buildExtensionRow(context, ext, attachedIds),
        if (!hasRows)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No extensions available',
              style: context.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildExtensionRow(
    BuildContext context,
    Extension ext,
    Set<String> attachedIds,
  ) {
    return InkWell(
      onTap: () => _toggleId(attachedIds, ext.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: attachedIds.contains(ext.id),
              onChanged: (_) {
                _toggleId(attachedIds, ext.id);
              },
            ),
            Expanded(child: Text(ext.name, style: context.bodyMedium)),
            if (_autoIds.contains(ext.id))
              DionBadge(
                child: Text('auto', style: context.bodySmall),
              ).paddingOnly(right: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownExtensionRow(
    BuildContext context,
    String id,
    Set<String> attachedIds,
  ) {
    return InkWell(
      onTap: () => _toggleId(attachedIds, id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: true,
              onChanged: (_) {
                _toggleId(attachedIds, id);
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id, style: context.bodyMedium),
                  Text(
                    'Extension not found',
                    style: context.bodySmall?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2, top: 10),
      child: Text(
        title,
        style: context.labelSmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildExtensionsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'ENTRY EXTENSIONS'),
        _buildExtensionRows(
          context,
          available: _availableExtensions<rust.ExtensionType_EntryProcessor>(),
          attachedIds: _entryExtensionIds,
        ),
        _buildSectionHeader(context, 'SOURCE EXTENSIONS'),
        _buildExtensionRows(
          context,
          available: _availableExtensions<rust.ExtensionType_SourceProcessor>(),
          attachedIds: _sourceExtensionIds,
        ),
      ],
    );
  }

  Widget _buildCategoriesTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'CATEGORIES'),
        FutureBuilder<List<Category>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final categories = snapshot.data!;
            if (categories.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No categories yet',
                  style: context.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in categories)
                  InkWell(
                    onTap: () => setState(() {
                      if (!_categories.remove(category)) {
                        _categories.add(category);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _categories.contains(category),
                            onChanged: (_) => setState(() {
                              if (!_categories.remove(category)) {
                                _categories.add(category);
                              }
                            }),
                          ),
                          Expanded(
                            child: Text(
                              category.name,
                              style: context.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        _buildSectionHeader(context, 'NEW CATEGORY'),
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: DionTextbox(
                  controller: _newCategoryController,
                  hintText: 'New category',
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              DionIconbutton(
                tooltip: 'Add Category',
                icon: const Icon(Icons.add),
                onPressed: _addCategory,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    final db = locate<Database>();
    final categories = await db.getCategories();
    final category = Category.construct(name, categories.length);
    await db.updateCategory(category);
    _newCategoryController.clear();
    if (mounted) {
      setState(() {
        _categoriesFuture = db.getCategories();
        _categories.add(category);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The panel is placed statically relative to the overlay instead of
    // following its anchor via a CompositedTransformFollower: a FollowerLayer
    // cannot provide a paint transform during layout, which makes the
    // Overlay's layout-info computation throw on every rebuild of this sheet.
    // The scrim blocks interaction with the page, so the anchor cannot move
    // while the picker is open and a static position is safe.
    return LayoutBuilder(
      builder: (context, overlayConstraints) {
        final overlaySize = overlayConstraints.biggest;
        final left = widget.anchor.left.clamp(
          8.0,
          overlaySize.width - _panelWidth - 8,
        );
        var top = widget.anchor.bottom + 8;
        if (overlaySize.height - top - 8 < 260) {
          // Not enough room below the button: keep a usable panel height by
          // shifting it up (possibly overlapping the button).
          top = overlaySize.height - 260 - 8;
        }
        final maxHeight = (overlaySize.height - top - 8).clamp(200.0, 420.0);
        return Stack(
          children: [
            // Scrim: invisible, swallows outside taps as a cancel.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: _panelWidth,
              child: FocusScope(
                node: _scopeNode,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.15,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.theme.colorScheme.onSurface.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DionTextbutton(
                                  type: _extensionsTab
                                      ? ButtonType.filled
                                      : ButtonType.ghost,
                                  onPressed: () => setState(() {
                                    _extensionsTab = true;
                                  }),
                                  child: const Text('EXTENSIONS'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DionTextbutton(
                                  type: !_extensionsTab
                                      ? ButtonType.filled
                                      : ButtonType.ghost,
                                  onPressed: () => setState(() {
                                    _extensionsTab = false;
                                  }),
                                  child: const Text('CATEGORIES'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: _extensionsTab
                                ? _buildExtensionsTab(context)
                                : _buildCategoriesTab(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: DionTextbutton(
                                  type: ButtonType.ghost,
                                  onPressed: _dismiss,
                                  child: const Text('CANCEL'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DionTextbutton(
                                  onPressed: () => widget.onCommit(
                                    LibraryPickerResult(
                                      _categories.toList(),
                                      Set.of(_entryExtensionIds),
                                      Set.of(_sourceExtensionIds),
                                    ),
                                  ),
                                  child: Text(
                                    _isSaved ? 'APPLY' : 'SAVE',
                                    style: context.labelMedium?.copyWith(
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
