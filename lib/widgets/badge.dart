import 'package:flutter/material.dart';

class DionBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  const DionBadge({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final double badgesize =
        (Theme.of(context).textTheme.labelMedium?.fontSize ?? 0) * 1.3;
    return Container(
      height: badgesize + 9,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: color??Theme.of(context).primaryColor,
      ),
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: child,
      ),
    );
  }
}
