import 'package:flutter/material.dart';

class Stardisplay extends StatelessWidget {
  final IconData icon;
  final double width;
  final double height;
  final double fill;
  final Color color;
  final Color bgcolor;
  final int maxstars;

  const Stardisplay(
      {super.key,
      this.icon = Icons.star,
      required this.width,
      required this.height,
      required this.fill,
      this.maxstars = 5,
      this.bgcolor = Colors.grey,
      this.color = Colors.white,})
      : assert(fill <= 1);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Rated ${(fill*100).round()/10}/10',
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (Rect rect) {
          return LinearGradient(
            stops: [0, fill, fill],
            colors: [color, color, color.withOpacity(0)],
          ).createShader(rect);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(
              icon,
              size: width,
              color: bgcolor,
            ),
          ),
        ),
      ),
    );
    // return Row(
    //   children: List.generate(
    //     maxstars,
    //     (index) => Icon(
    //       icon,
    //       size: width,
    //       color: color,
    //     ),
    //   ),
    // );
  }
}
