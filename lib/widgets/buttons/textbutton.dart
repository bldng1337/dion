import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ButtonType { ghost, filled, elevated }

class DionTextbutton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final ButtonType type;
  final Widget child;
  final Color? color;
  const DionTextbutton({
    super.key,
    this.onPressed,
    this.color,
    required this.child,
    this.type = ButtonType.filled,
  });

  ButtonStyle _getStyle(BuildContext context) => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return switch (type) {
        ButtonType.ghost => Colors.transparent,
        ButtonType.filled =>
          color ??
              (onPressed == null
                  ? context.theme.disabledColor.lighten(70)
                  : states.contains(WidgetState.hovered)
                  ? context.theme.colorScheme.primary.lighten(10)
                  : context.theme.colorScheme.primary),
        ButtonType.elevated =>
          onPressed == null
              ? context.theme.disabledColor.lighten(70)
              : context.theme.colorScheme.primary.withValues(alpha: 0.08),
      };
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return switch (type) {
        ButtonType.ghost =>
          onPressed == null
              ? context.theme.disabledColor
              : context.theme.colorScheme.primary,
        ButtonType.filled =>
          onPressed == null
              ? context.theme.disabledColor
              : context.theme.colorScheme.onPrimary,
        ButtonType.elevated =>
          onPressed == null
              ? context.theme.disabledColor
              : context.theme.colorScheme.primary,
      };
    }),
    shape: switch (type) {
      ButtonType.elevated => WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(
            color:
                color ??
                (onPressed == null
                    ? context.theme.disabledColor
                    : context.theme.colorScheme.primary.withValues(alpha: 0.3)),
            width: 0.5,
          ),
        ),
      ),
      ButtonType.ghost => WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(
            color: onPressed == null
                ? context.theme.disabledColor
                : context.theme.colorScheme.primary,
            width: 0.3,
          ),
        ),
      ),
      _ => WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    },
    overlayColor: WidgetStateProperty.resolveWith((states) {
      return switch (type) {
        ButtonType.ghost || ButtonType.elevated =>
          context.theme.colorScheme.primary.withValues(alpha: 0.1),
        ButtonType.filled => context.theme.colorScheme.onPrimary.withValues(
          alpha: 0.1,
        ),
      };
    }),
  );

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
        loading: TextButton(
          style: _getStyle(context),
          onPressed: null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0.3, child: child),
              const DionProgressBar(color: Colors.white, size: 16),
            ],
          ),
        ),
        builder: (context, _, setFuture) => TextButton(
          style: _getStyle(context),
          onPressed: () {
            setFuture(onPressed?.call());
          },
          child: child,
        ),
      ),
      DionThemeMode.cupertino => CupertinoButton(
        onPressed: onPressed,
        child: child,
      ),
    };
  }
}
