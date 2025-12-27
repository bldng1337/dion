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
  const ActionButton({super.key, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
        loading: FloatingActionButton(
          backgroundColor: onPressed == null
              ? context.theme.disabledColor.lighten(70)
              : context.theme.colorScheme.primary,
          foregroundColor: onPressed == null
              ? context.theme.disabledColor
              : context.theme.colorScheme.onPrimary,
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
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          backgroundColor: onPressed == null
              ? context.theme.disabledColor.lighten(50)
              : context.theme.colorScheme.primary,
          // foregroundColor: onPressed == null
          //     ? context.theme.disabledColor
          //     : context.theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: onPressed == null
                  ? context.theme.disabledColor
                  : context.theme.colorScheme.primary,
              width: 0.3,
            ),
          ),
          onPressed: () {
            setFuture(onPressed?.call());
          },
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      DionThemeMode.cupertino => CupertinoButton.filled(
        borderRadius: BorderRadius.circular(3),
        color: onPressed == null
            ? CupertinoColors.systemGrey4
            : CupertinoTheme.of(context).primaryColor,
        disabledColor: CupertinoColors.systemGrey4,
        onPressed: onPressed,
        child: child ?? const SizedBox.shrink(),
      ),
    };
  }
}
