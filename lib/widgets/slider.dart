// ignore_for_file: type_literal_in_constant_pattern

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SquareSliderThumbShape extends SliderComponentShape {
  final double thumbSize;
  final double borderRadius;

  const SquareSliderThumbShape({this.thumbSize = 12, this.borderRadius = 3});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbSize / 2);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Color? thumbColor = sliderTheme.thumbColor;
    final enabledThumbRadius = thumbSize / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: thumbSize, height: thumbSize),
        Radius.circular(borderRadius),
      ),
      Paint()..color = thumbColor ?? Colors.white,
    );
  }
}

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
    final theme = context.theme;
    return switch (context.diontheme.mode) {
      DionThemeMode.material => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const SquareSliderThumbShape(
            thumbSize: 12,
            borderRadius: 3,
          ),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          trackShape: const RoundedRectSliderTrackShape(),
          activeTrackColor: theme.colorScheme.primary,
          inactiveTrackColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.2,
          ),
          thumbColor: theme.colorScheme.primary,
          overlayColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          disabledActiveTrackColor: theme.disabledColor.withValues(alpha: 0.5),
          disabledInactiveTrackColor: theme.disabledColor.withValues(
            alpha: 0.1,
          ),
          disabledThumbColor: theme.disabledColor,
        ),
        child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          onChanged: onChanged != null
              ? (val) => onChanged!(convert(val))
              : null,
          onChangeStart: onChangeStart != null
              ? (val) => onChangeStart!(convert(val))
              : null,
          onChangeEnd: onChangeEnd != null
              ? (val) => onChangeEnd!(convert(val))
              : null,
        ),
      ),
      DionThemeMode.cupertino => CupertinoSlider(
        value: value.toDouble(),
        onChanged: onChanged != null ? (val) => onChanged!(convert(val)) : null,
        onChangeStart: onChangeStart != null
            ? (val) => onChangeStart!(convert(val))
            : null,
        onChangeEnd: onChangeEnd != null
            ? (val) => onChangeEnd!(convert(val))
            : null,
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: (value is int) ? (max - min).abs().toInt() : null,
        activeColor: theme.colorScheme.primary,
        thumbColor: theme.colorScheme.primary,
      ),
    };
  }
}
