import 'package:flutter/widgets.dart';

Color getColor(String s, {num saturation = 70, num brightness = 70}) {
  final hue = ((s.hashCode / 100) % 360000) / 1000;
  final hsv =
      HSVColor.fromAHSV(1, hue, saturation.toDouble()/100, brightness.toDouble()/100);
  return hsv.toColor();
}

extension StringColorExt on String {
  Color get color => getColor(this);
}
