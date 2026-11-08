import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionIconbutton extends StatelessWidget {
  final String? tooltip;
  final FutureOr<void> Function()? onPressed; // ignore: avoid_futureor_void
  final FutureOr<void> Function()? onLongPress; // ignore: avoid_futureor_void
  final Widget? icon;
  const DionIconbutton({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.icon,
    this.tooltip,
  });

  ButtonStyle _getButtonStyle(BuildContext context) {
    return ButtonStyle(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      // Keep the tappable area at an accessible size even for small icons.
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return context.theme.colorScheme.primary.withValues(alpha: 0.07);
        }
        return Colors.transparent;
      }),
      animationDuration: const Duration(milliseconds: 10),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (onPressed == null) {
          return context.theme.disabledColor;
        }
        final primary = context.theme.colorScheme.primary;
        final dark = context.theme.brightness == Brightness.dark;
        if (states.contains(WidgetState.hovered) != dark) {
          return primary.lighten(60);
        }
        return primary.darken(60);
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
          onLongPress: onLongPress == null
              ? null
              : () {
                  setFuture(onLongPress!.call());
                },
          style: _getButtonStyle(context),
        ),
      ),
      DionThemeMode.cupertino => _buildCupertino(context),
    };
  }

  Widget _buildCupertino(BuildContext context) {
    final button = CupertinoButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      child: icon ?? const Icon(Icons.question_mark),
    );
    // CupertinoButton has no tooltip support, so provide the accessible
    // label via a Tooltip wrapper.
    final label = tooltip;
    if (label == null) return button;
    return Tooltip(message: label, child: button);
  }
}
