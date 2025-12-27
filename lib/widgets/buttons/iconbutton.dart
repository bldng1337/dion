import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionIconbutton extends StatelessWidget {
  final String? tooltip;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;
  const DionIconbutton({super.key, this.onPressed, this.icon, this.tooltip});

  ButtonStyle _getButtonStyle(BuildContext context) {
    return ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          // side: BorderSide(
          //   color: onPressed == null
          //       ? context.theme.disabledColor
          //       : context.theme.colorScheme.primary,
          //   width: 0.3,
          // ),
        ),
      ),
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return context.theme.colorScheme.primary.withValues(alpha: 0.1);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (onPressed == null) {
          return context.theme.disabledColor;
        }
        if (states.contains(WidgetState.hovered)) {
          return context.theme.colorScheme.primary.lighten(60);
        }
        return context.theme.colorScheme.primary.darken(60);
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
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.3,
                child: icon ?? const Icon(Icons.question_mark),
              ),
              const DionProgressBar(size: 16),
            ],
          ),
        ),
        builder: (context, _, setFuture) => IconButton(
          icon: icon ?? const Icon(Icons.question_mark),
          tooltip: tooltip,
          onPressed: () {
            setFuture(onPressed?.call());
          },
          style: _getButtonStyle(context),
        ),
      ),
      DionThemeMode.cupertino => CupertinoButton(
        onPressed: onPressed,
        child: icon ?? const Icon(Icons.question_mark),
      ),
    };
  }
}
