import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';

class Stardisplay extends StatelessWidget {
  final IconData icon;
  final double width;
  final double height;
  final double fill;
  final Color color;
  final Color bgcolor;
  final int maxstars;
  final String? semanticLabel;

  const Stardisplay({
    super.key,
    this.icon = Icons.star,
    required this.width,
    required this.height,
    required this.fill,
    this.maxstars = 5,
    this.bgcolor = Colors.grey,
    this.color = Colors.white,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (fill >= 1) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label:
          semanticLabel ??
          'Rating ${(fill * maxstars).toStringAsFixed(1)} of $maxstars',
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (Rect rect) {
          return LinearGradient(
            stops: [0, fill, fill],
            colors: [color, color, color.withValues(alpha: 0)],
          ).createShader(rect);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(icon, size: width, color: bgcolor),
          ),
        ),
      ),
    );
  }
}

class StarRatingInput extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final int maxStars;
  final double size;
  final Color? color;

  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxStars = 5,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFE5A500);
    final dimColor = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.25);
    return Semantics(
      label: value == null
          ? 'No rating yet, tap a star to rate'
          : 'Your rating: $value of $maxStars stars, tap the current star to '
                'clear',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= maxStars; i++)
            Semantics(
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onChanged(value == i ? null : i),
                borderRadius: BorderRadius.circular(DionRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(DionSpacing.xs),
                  child: Icon(
                    value != null && i <= value!
                        ? Icons.star
                        : Icons.star_border,
                    size: size,
                    color: value != null && i <= value!
                        ? effectiveColor
                        : dimColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
