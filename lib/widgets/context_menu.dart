import 'package:dionysos/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class ContextMenuItem {
  final String label;
  final IconData? icon;
  final Future<void> Function()? onTap;

  /// Section header rendered above this item in drawer menus, grouping
  /// related actions (e.g. actions vs selection modifiers).
  final String? section;
  final bool isDestructive;
  const ContextMenuItem({
    required this.label,
    this.onTap,
    this.icon,
    this.section,
    this.isDestructive = false,
  });
}

class ContextMenu extends StatefulWidget {
  const ContextMenu({
    required this.child,
    required this.contextItems,
    this.active = true,
    this.selectionActive = false,
    this.selectionCount,
  });
  final bool selectionActive;
  final bool active;

  /// Number of currently selected items, shown as the title of the mobile
  /// selection drawer.
  final int? selectionCount;
  final List<ContextMenuItem> contextItems;

  final Widget child;

  @override
  State<ContextMenu> createState() => ContextMenuState();
}

class ContextMenuState extends State<ContextMenu> with StateDisposeScopeMixin {
  Offset? _longPressOffset;

  late final ContextMenuController _contextMenuController;
  PersistentBottomSheetController? _bottomSheetController;

  /// Bumped on every widget update so the open selection drawer re-reads
  /// [widget.contextItems]; labels and count depend on the current selection.
  late final ValueNotifier<int> _selectionRevision;

  @override
  void initState() {
    _contextMenuController = ContextMenuController(
      onRemove: () {
        if (mounted) setState(() {});
      },
    );
    _selectionRevision = ValueNotifier<int>(0)..disposedBy(scope);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectionActive) {
      _closeSelectionDrawer();
    } else if (isMobilePlatform) {
      if (_bottomSheetController == null) {
        _openSelectionDrawer();
      } else {
        // Notifying during didUpdateWidget would mark the sheet's builder
        // dirty mid-build; defer until the current build finished.
        Future.microtask(() {
          if (mounted) _selectionRevision.value++;
        });
      }
    }
  }

  void _openSelectionDrawer() {
    Future.microtask(() {
      if (!mounted || _bottomSheetController != null) return;
      final controller = Scaffold.of(context).showBottomSheet(
        (sheetContext) => ValueListenableBuilder<int>(
          valueListenable: _selectionRevision,
          builder: (context, _, _) => DionDrawer(
            title: widget.selectionCount == null
                ? null
                : Text('${widget.selectionCount} selected'),
            child: DionDrawerMenu(
              items: [
                for (final item in widget.contextItems)
                  DionDrawerItem(
                    label: Text(item.label),
                    icon: item.icon,
                    onTap: item.onTap,
                    section: item.section,
                    isDestructive: item.isDestructive,
                  ),
              ],
              // Selection stays active after most actions; the drawer closes
              // itself once the selection is cleared.
              closeOnTap: false,
            ),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      );
      _bottomSheetController = controller;
      controller.closed.then((_) {
        if (mounted && identical(_bottomSheetController, controller)) {
          setState(() {
            _bottomSheetController = null;
          });
        }
      });
    });
  }

  void _closeSelectionDrawer() {
    final controller = _bottomSheetController;
    if (controller == null) return;
    _bottomSheetController = null;
    Future.microtask(() => controller.close());
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    _show(details.globalPosition);
  }

  void _onTap() {
    if (!_contextMenuController.isShown) {
      return;
    }
    _hide();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _longPressOffset = details.globalPosition;
  }

  void _onLongPress() {
    assert(_longPressOffset != null);
    _show(_longPressOffset!);
    _longPressOffset = null;
  }

  void _show(Offset position) {
    if (isMobilePlatform) {
      showDionMenuDrawer(
        context: context,
        items: [
          for (final item in widget.contextItems)
            DionDrawerItem(
              label: Text(item.label),
              icon: item.icon,
              onTap: item.onTap,
              section: item.section,
              isDestructive: item.isDestructive,
            ),
        ],
      );
      return;
    }
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: position),
          buttonItems: widget.contextItems
              .map(
                (e) => ContextMenuButtonItem(
                  label: e.label,
                  onPressed: e.onTap != null
                      ? () async {
                          await e.onTap!();
                          _hide();
                        }
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
    setState(() {});
  }

  void _hide() {
    _contextMenuController.remove();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: _onSecondaryTapUp,
      onTap: _onTap,
      onLongPress: isMobilePlatform ? _onLongPress : null,
      onLongPressStart: isMobilePlatform ? _onLongPressStart : null,
      child: AbsorbPointer(
        absorbing: _contextMenuController.isShown,
        child: widget.child,
      ),
    );
  }
}
