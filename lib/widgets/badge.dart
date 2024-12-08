import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';

class DionBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  const DionBadge({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: color??context.theme.primaryColor,
      ),
      child: Center(
        child: child,
      ).paddingAll(3),
    ).paddingAll(3);
  }
}
