import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:flutter/material.dart'
    show Checkbox, CircularProgressIndicator, Colors, Icons, InkWell, Material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

/// Edits the categories of a saved entry: a panel anchored to the entry card
/// in the root overlay on desktop, a bottom drawer on mobile.
///
/// [anchor] is only used on desktop; the caller measures it relative to the
/// root overlay the panel is inserted into. Closing without applying keeps
/// the entry's old categories.
Future<void> showEditCategories(
  BuildContext context, {
  required Rect anchor,
  required EntrySaved entry,
}) async {
  if (isMobilePlatform) {
    final categories = await showDionDrawer<List<Category>>(
      context: context,
      title: const Text('Edit Categories'),
      builder: (sheetContext) => _CategoryPickerBody(
        entry: entry,
        onDismiss: () => Navigator.pop(sheetContext),
        onCommit: (categories) => Navigator.pop(sheetContext, categories),
      ),
    );
    if (categories == null) return;
    await _assignCategories(entry, categories);
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => _CategoryPickerOverlay(
      anchor: anchor,
      entry: entry,
      onDismiss: () => overlayEntry.remove(),
      onCommit: (categories) {
        overlayEntry.remove();
        _assignCategories(entry, categories);
      },
    ),
  );
  overlay.insert(overlayEntry);
}

Future<void> _assignCategories(
  EntrySaved entry,
  List<Category> categories,
) async {
  entry.categories = categories;
  try {
    await entry.save();
  } catch (e) {
    logger.e('Failed to save entry', error: e);
  }
}

/// Anchored panel in the root overlay, mirroring the LibrarySaveSheet picker.
class _CategoryPickerOverlay extends StatefulWidget {
  final Rect anchor;
  final EntrySaved entry;
  final VoidCallback onDismiss;
  final void Function(List<Category> categories) onCommit;

  const _CategoryPickerOverlay({
    required this.anchor,
    required this.entry,
    required this.onDismiss,
    required this.onCommit,
  });

  @override
  State<_CategoryPickerOverlay> createState() => _CategoryPickerOverlayState();
}

class _CategoryPickerOverlayState extends State<_CategoryPickerOverlay>
    with StateDisposeScopeMixin {
  static const _panelWidth = 340.0;
  static const _minPanelHeight = 260.0;

  bool _dismissed = false;
  late final _scopeNode = FocusScopeNode()..disposedBy(scope);

  @override
  void initState() {
    super.initState();
    // Pull focus into the panel's scope once mounted so Escape reaches its
    // handler even though the page below already holds focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scopeNode.requestFocus();
      }
    });
    KeyObserver(_handleKey).disposedBy(scope);
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      return true;
    }
    return false;
  }

  /// Dismissal without the apply button cancels all changes.
  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    // The panel is placed statically relative to the overlay from the
    // pre-measured anchor instead of following it: the scrim blocks
    // interaction with the page, so the anchor cannot move while open.
    return LayoutBuilder(
      builder: (context, overlayConstraints) {
        final overlaySize = overlayConstraints.biggest;
        final left = widget.anchor.left.clamp(
          8.0,
          overlaySize.width - _panelWidth - 8,
        );
        var top = widget.anchor.bottom + 8;
        if (overlaySize.height - top - 8 < _minPanelHeight) {
          // Not enough room below the card: keep a usable panel height by
          // shifting it up (possibly overlapping the card).
          top = overlaySize.height - _minPanelHeight - 8;
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
                    child: _CategoryPickerBody(
                      entry: widget.entry,
                      onDismiss: _dismiss,
                      onCommit: widget.onCommit,
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

/// Surface-agnostic picker content: category rows, a new-category input and
/// cancel/apply actions. Placement (overlay panel or bottom drawer) is the
/// caller's concern.
class _CategoryPickerBody extends StatefulWidget {
  final EntrySaved entry;
  final VoidCallback onDismiss;
  final void Function(List<Category> categories) onCommit;

  const _CategoryPickerBody({
    required this.entry,
    required this.onDismiss,
    required this.onCommit,
  });

  @override
  State<_CategoryPickerBody> createState() => _CategoryPickerBodyState();
}

class _CategoryPickerBodyState extends State<_CategoryPickerBody>
    with StateDisposeScopeMixin {
  final Set<Category> _categories = {};
  late final _newCategoryController = TextEditingController()
    ..disposedBy(scope);
  late Future<List<Category>> _categoriesFuture = locate<Database>()
      .getCategories();

  @override
  void initState() {
    super.initState();
    _categories.addAll(widget.entry.categories);
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

  void _toggle(Category category) {
    setState(() {
      if (!_categories.remove(category)) {
        _categories.add(category);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DionSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, 'CATEGORIES'),
                FutureBuilder<List<Category>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(DionSpacing.md),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final categories = snapshot.data!;
                    if (categories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(DionSpacing.md),
                        child: Text(
                          'No categories yet',
                          style: context.bodyMedium?.copyWith(
                            color: context.theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
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
                            onTap: () => _toggle(category),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DionSpacing.sm,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _categories.contains(category),
                                    onChanged: (_) => _toggle(category),
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
                  padding: const EdgeInsets.only(
                    left: DionSpacing.sm,
                    right: DionSpacing.sm,
                    bottom: DionSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DionTextbox(
                          controller: _newCategoryController,
                          hintText: 'New category',
                          onSubmitted: (_) => _addCategory(),
                        ),
                      ),
                      const SizedBox(width: DionSpacing.sm),
                      DionIconbutton(
                        tooltip: 'Add Category',
                        icon: const Icon(Icons.add),
                        onPressed: _addCategory,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DionSpacing.md,
            0,
            DionSpacing.md,
            DionSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: DionTextbutton(
                  type: ButtonType.ghost,
                  onPressed: widget.onDismiss,
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: DionSpacing.sm),
              Expanded(
                child: DionTextbutton(
                  onPressed: () => widget.onCommit(_categories.toList()),
                  child: const Text('APPLY'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
