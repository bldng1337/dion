import 'dart:ui';

import 'package:flutter_color_models/flutter_color_models.dart';

Color getColor(String s,{num saturation=70,num brightness=70}) {
  final hue=((s.hashCode/100)%360000)/1000;
  return HsbColor(hue, saturation, brightness);
}
