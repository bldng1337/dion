import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/routes.dart';
import 'package:flutter/material.dart';

class DionBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  const DionBadge({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: color??context.primaryColor,
      ),
      padding: const EdgeInsets.all(1),
      margin: const EdgeInsets.all(3),
      child: Center(
        child: child,
      ),
    );
  }
}
