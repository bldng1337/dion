import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';

class SettingTileWrapper extends StatelessWidget {
  final Widget child;
  const SettingTileWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.theme.dividerColor.withOpacity(0.1)),
      ),
      child: child,
    ).paddingSymmetric(horizontal: 10, vertical: 5);
  }
}
