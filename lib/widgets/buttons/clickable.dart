import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Clickable extends StatefulWidget {
  final Widget child;
  final Function()? onTap;
  final Function()? onLongTap;
  const Clickable({super.key, required this.child, this.onTap, this.onLongTap});

  @override
  State<Clickable> createState() => _ClickableState();
}

class _ClickableState extends State<Clickable> {
  bool _hover = false;
  bool _focused = false;

  static const _activations = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongTap != null;
    final highlighted = _hover || _focused;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor:
          enabled ? SystemMouseCursors.click : MouseCursor.defer,
      shortcuts: _activations,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowHoverHighlight: (value) => setState(() => _hover = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          //InkWell TODO: Maybe revisit InkWell for some things
          // borderRadius: BorderRadius.circular(3),
          onTap: widget.onTap,
          onLongPress: widget.onLongTap,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              widget.child,
              if (highlighted)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      color: DionTheme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.07),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
