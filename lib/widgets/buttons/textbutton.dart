import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionTextbutton extends StatelessWidget {
  final Function()? onPressed;
  final Widget child;
  const DionTextbutton({super.key, this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => TextButton(
          onPressed: onPressed,
          child: child,
        ),
      DionThemeMode.cupertino => CupertinoButton(
          onPressed: onPressed,
          child: child,
        ),
    };
  }
}
