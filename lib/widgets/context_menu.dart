import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ContextMenuItem {
  final String label;
  final Future<void> Function()? onTap;
  const ContextMenuItem({required this.label, this.onTap});
}

class ContextMenu extends StatefulWidget {
  const ContextMenu({
    required this.child,
    required this.contextItems,
    this.active = true,
    this.selectionActive = false,
  });
  final bool selectionActive;
  final bool active;
  final List<ContextMenuItem> contextItems;

  final Widget child;

  @override
  State<ContextMenu> createState() => ContextMenuState();
}

class ContextMenuState extends State<ContextMenu> {
  Offset? _longPressOffset;

  late final ContextMenuController _contextMenuController;
  PersistentBottomSheetController? _bottomSheetController;

  @override
  void initState() {
    _contextMenuController = ContextMenuController(
      onRemove: () {
        if (mounted) setState(() {});
      },
    );
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("ContextMenu didChangeDependencies");
    print(widget.selectionActive);
    print(_drawerEnabled);
    print(_bottomSheetController);
    if (!widget.selectionActive) {
      Future.microtask(() async {
        _bottomSheetController?.close();
        _bottomSheetController = null;
      });
    } else if (_drawerEnabled && _bottomSheetController == null) {
      print("Showing bottom sheet");
      Future.microtask(() async {
        if (!mounted) return;
        _bottomSheetController = Scaffold.of(context).showBottomSheet(
          (BuildContext context) => SizedBox(
            height: 50,
            child: ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: widget.contextItems
                  .map(
                    (e) => DionTextbutton(
                      onPressed: e.onTap != null
                          ? () async {
                              await e.onTap!();
                              _bottomSheetController?.close();
                              _bottomSheetController = null;
                            }
                          : null,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  static bool get _drawerEnabled {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  static bool get _longPressEnabled {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
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
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(
            primaryAnchor: position,
          ),
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
      onLongPress: _longPressEnabled ? _onLongPress : null,
      onLongPressStart: _longPressEnabled ? _onLongPressStart : null,
      child: AbsorbPointer(
        absorbing: _contextMenuController.isShown,
        child: widget.child,
      ),
    );
  }
}
