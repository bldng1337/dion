import 'package:flutter/material.dart';

class DionTextScroll extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const DionTextScroll(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
