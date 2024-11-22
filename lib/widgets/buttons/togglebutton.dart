import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class Togglebutton extends StatelessWidget {
  final void Function()? onPressed;
  final bool selected;
  const Togglebutton(
      {super.key, this.onPressed, required this.selected});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Switch(
          // ignore: prefer_null_aware_method_calls
          onChanged: (val) => onPressed != null ? onPressed!() : null,
          value: selected,
        ),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}
