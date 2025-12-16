import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';

class DionBadge extends StatelessWidget {
  final Widget child;
  final Color? color;
  final bool noPadding;
  final bool noMargin;
  const DionBadge({
    super.key,
    required this.child,
    this.color,
    this.noMargin = false,
    this.noPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color:
            color ??
            context.theme.colorScheme.surfaceContainer.withValues(alpha: 0.85),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: child.paddingAll(noPadding ? 0 : 3),
      ),
    ).paddingAll(noMargin ? 0 : 3);
  }
}
