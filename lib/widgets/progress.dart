import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

enum DionProgressType { linear, circular }

class DionProgressBar extends StatelessWidget {
  final double? value;
  final double max;
  final DionProgressType type;
  const DionProgressBar({
    super.key,
    this.value,
    this.max = 1,
    this.type = DionProgressType.circular,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      DionProgressType.linear => material.CircularProgressIndicator(
        value: value != null ? value! / max : null,
      ),
      DionProgressType.circular => material.CircularProgressIndicator(
        value: value != null ? value! / max : null,
      ),
    };
  }
}
