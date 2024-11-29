import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';

class Selection extends StatelessWidget {
  final Widget child;
  const Selection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return switch (DionTheme.of(context).mode) {
      DionThemeMode.material => SelectionArea(child: child),
      DionThemeMode.cupertino => child,
    };
  }
}
