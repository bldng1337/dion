import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:flutter/material.dart';

class Selection extends StatefulWidget {
  final Widget child;

  final List<ContextMenuItem> Function(String selectedText)?
  selectionContextItems;

  const Selection({
    super.key,
    required this.child,
    this.selectionContextItems,
  });

  @override
  State<Selection> createState() => _SelectionState();
}

class _SelectionState extends State<Selection> {
  String? _selectedText;

  @override
  Widget build(BuildContext context) {
    final itemBuilder = widget.selectionContextItems;
    return switch (DionTheme.of(context).mode) {
      DionThemeMode.material => SelectionArea(
        onSelectionChanged: itemBuilder == null
            ? null
            : (content) {
                _selectedText = content?.plainText;
              },
        contextMenuBuilder: itemBuilder == null
            ? null
            : (context, state) {
                final text = _selectedText?.trim();
                final extra = (text != null && text.isNotEmpty)
                    ? itemBuilder(text)
                    : const <ContextMenuItem>[];
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: state.contextMenuAnchors,
                  buttonItems: [
                    for (final item in extra)
                      ContextMenuButtonItem(
                        label: item.label,
                        onPressed: item.onTap != null
                            ? () async {
                                await item.onTap!();
                                state.hideToolbar();
                              }
                            : null,
                      ),
                    ...state.contextMenuButtonItems,
                  ],
                );
              },
        child: widget.child,
      ),
      DionThemeMode.cupertino => widget.child,
    };
  }
}
