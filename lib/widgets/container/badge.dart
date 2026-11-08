import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';

class DionBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  const DionBadge({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color ?? context.theme.colorScheme.primary.lighten(),
        borderRadius: BorderRadius.circular(DionRadius.xs),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(DionRadius.sm)),
        child: child,
      ),
    );
  }
}
