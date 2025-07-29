import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class Togglebutton extends StatelessWidget {
  final void Function()? onPressed;
  final bool selected;
  const Togglebutton({super.key, this.onPressed, required this.selected});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Switch(
        onChanged: (val) => onPressed?.call(),
        value: selected,
      ),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}
