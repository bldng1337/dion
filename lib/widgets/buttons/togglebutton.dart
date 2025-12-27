import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Togglebutton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final bool selected;
  final Widget? icon;
  final Widget? selectedIcon;
  final String? tooltip;

  const Togglebutton({
    super.key,
    this.onPressed,
    required this.selected,
    this.icon,
    this.selectedIcon,
    this.tooltip,
  });

  ButtonStyle _getButtonStyle(BuildContext context) {
    return ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        return context.theme.colorScheme.primary.withValues(alpha: 0.1);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (onPressed == null) {
          return context.theme.disabledColor;
        }
        if (states.contains(WidgetState.hovered)) {
          return context.theme.colorScheme.primary.lighten(20);
        }
        if (selected) {
          return context.theme.colorScheme.primary;
        }
        return context.theme.colorScheme.primary.darken(5);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
        loading: IconButton(
          style: _getButtonStyle(context),
          onPressed: null,
          tooltip: tooltip,
          icon: Icon(
            Icons.check_box_outline_blank,
            color: context.theme.disabledColor,
          ),
        ),
        builder: (context, _, setFuture) => IconButton(
          onPressed: onPressed != null
              ? () {
                  setFuture(onPressed?.call());
                }
              : null,
          style: _getButtonStyle(context),
          tooltip: tooltip,
          icon: selected
              ? selectedIcon ?? Icon(Icons.check_box, size: 20)
              : icon ?? Icon(Icons.check_box_outline_blank, size: 20),
        ),
      ),
      DionThemeMode.cupertino => CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? CupertinoColors.systemGrey
                  : CupertinoColors.systemGrey4,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
            color: selected
                ? CupertinoColors.systemGrey.withOpacity(0.1)
                : CupertinoColors.systemGrey6,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(
            selected ? CupertinoIcons.checkmark_square : CupertinoIcons.square,
            color: selected
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemGrey,
            size: 20,
          ),
        ),
      ),
    };
  }
}
