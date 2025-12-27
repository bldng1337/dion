import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

enum DionProgressType { linear, circular }

class DionProgressBar extends StatelessWidget {
  final double? value;
  final double max;
  final double? size;
  final Color? color;
  final DionProgressType type;
  const DionProgressBar({
    super.key,
    this.value,
    this.max = 1,
    this.type = DionProgressType.circular,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      DionProgressType.linear => material.CircularProgressIndicator(
        value: value != null ? value! / max : null,
        color: color,
        strokeWidth: 2,
        constraints: size != null
            ? BoxConstraints.expand(height: size, width: size)
            : null,
      ),
      DionProgressType.circular => material.CircularProgressIndicator(
        value: value != null ? value! / max : null,
        color: color,
        strokeWidth: 2,
        constraints: size != null
            ? BoxConstraints.expand(height: size, width: size)
            : null,
      ),
    };
  }
}
