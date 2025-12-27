import 'package:flutter/cupertino.dart';
import 'package:awesome_extensions/awesome_extensions.dart';

enum ContainerType { ghost, filled, outlined }

class DionContainer extends StatelessWidget {
  final Widget child;
  final ContainerType? type;
  final Color? color;
  final Color? borderColor;
  final double? width;
  final Alignment alignment;
  final double? height;
  final bool emphasized;

  const DionContainer({
    super.key,
    required this.child,
    this.type,
    this.emphasized = false,
    this.color,
    this.borderColor,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color:
            color ??
            (type == ContainerType.filled
                ? context.theme.colorScheme.primary.lighten(20)
                : null),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color:
              borderColor ??
              color?.darken() ??
              context.theme.colorScheme.onSurface.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: context.theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      width: width,
      height: height,
      child: child,
    );
  }
}
