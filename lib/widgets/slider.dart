// ignore_for_file: type_literal_in_constant_pattern

import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionSlider<T extends num> extends StatelessWidget {
  final T value;
  final T min;
  final T max;
  final T? step;
  final void Function(T)? onChanged;
  final void Function(T)? onChangeEnd;
  final void Function(T)? onChangeStart;
  const DionSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
    this.onChangeEnd,
    this.onChangeStart,
    this.step,
  });

  T convert(num value) => switch (T) {
    int => value.toInt() as T,
    double => value.toDouble() as T,
    _ => throw UnimplementedError(),
  };

  int? get divisions {
    final step = this.step;
    if (step != null) return ((max - min).abs() / step).round();
    if (value is int) return (max - min).abs().toInt();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Slider(
        value: value.toDouble(),
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: divisions,
        onChanged: (val) {
          if (onChanged == null) return;
          onChanged!(convert(val));
        },
        onChangeStart: (val) {
          if (onChangeStart == null) return;
          onChangeStart!(convert(val));
        },
        onChangeEnd: (val) {
          if (onChangeEnd == null) return;
          onChangeEnd!(convert(val));
        },
      ),
      DionThemeMode.cupertino => CupertinoSlider(
        value: value.toDouble(),
        onChanged: (val) {
          if (onChanged == null) return;
          onChanged!(convert(val));
        },
        onChangeStart: (val) {
          if (onChangeStart == null) return;
          onChangeStart!(convert(val));
        },
        onChangeEnd: (val) {
          if (onChangeEnd == null) return;
          onChangeEnd!(convert(val));
        },
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: (value is int) ? (max - min).abs().toInt() : null,
      ),
    };
  }
}
