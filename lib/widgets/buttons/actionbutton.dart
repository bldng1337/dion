import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final Widget? child;
  final Function()? onPressed;
  const ActionButton({super.key, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => FloatingActionButton(
          onPressed: onPressed,
          child: child,
        ),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}
