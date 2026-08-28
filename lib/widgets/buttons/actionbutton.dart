import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final Widget? child;
  final Future<void>? Function()? onPressed;
  final String? tooltip;
  const ActionButton({super.key, this.onPressed, this.child, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
        loading: FloatingActionButton(
          backgroundColor: onPressed == null
              ? context.theme.disabledColor.lighten(70)
              : context.theme.appBarTheme.backgroundColor,
          foregroundColor: onPressed == null
              ? context.theme.disabledColor
              : context.theme.appBarTheme.foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: onPressed == null
                  ? context.theme.disabledColor
                  : context.theme.colorScheme.primary,
              width: 0.3,
            ),
          ),
          onPressed: null,
          tooltip: tooltip,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (child != null) Opacity(opacity: 0.3, child: child),
              DionProgressBar(
                color: context.theme.colorScheme.onPrimary,
                size: 24,
              ),
            ],
          ),
        ),
        builder: (context, _, setFuture) => FloatingActionButton(
          backgroundColor: onPressed == null
              ? context.theme.disabledColor.lighten(70)
              : context.theme.appBarTheme.backgroundColor,
          foregroundColor: onPressed == null
              ? context.theme.disabledColor
              : context.theme.appBarTheme.foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: onPressed == null
                  ? context.theme.disabledColor
                  : context.theme.colorScheme.primary,
              width: 0.3,
            ),
          ),
          // Keep the button disabled (also in the semantics tree) when there
          // is no callback instead of wrapping the null call in a closure.
          onPressed: onPressed == null
              ? null
              : () {
                  setFuture(onPressed?.call());
                },
          tooltip: tooltip,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      DionThemeMode.cupertino => _buildCupertino(context),
    };
  }

  Widget _buildCupertino(BuildContext context) {
    final button = CupertinoButton.filled(
      borderRadius: BorderRadius.circular(3),
      color: onPressed == null
          ? CupertinoColors.systemGrey4
          : CupertinoTheme.of(context).primaryColor,
      disabledColor: CupertinoColors.systemGrey4,
      onPressed: onPressed,
      child: child ?? const SizedBox.shrink(),
    );
    // CupertinoButton has no tooltip support, so provide the accessible
    // label via a Tooltip wrapper.
    final label = tooltip;
    if (label == null) return button;
    return Tooltip(message: label, child: button);
  }
}
