import 'package:dionysos/data/font.dart';
import 'package:dionysos/utils/async.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';

class DionFontText extends StatelessWidget {
  final String text;
  final Font font;
  final FontType? only;
  final TextStyle? style;

  const DionFontText({
    super.key,
    required this.text,
    required this.font,
    this.only,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (only != null && only != font.type) {
      return Text(text, style: style);
    }
    switch (font.type) {
      case FontType.system:
        return LoadingBuilder(
          future: SystemFonts().loadFont(font.name),
          builder: (context, loadedFont) {
            return Text(
              text,
              style:
                  style?.copyWith(fontFamily: loadedFont) ??
                  TextStyle(fontFamily: loadedFont),
            );
          },
        );
      case FontType.google:
        return Text(text, style: GoogleFonts.getFont(font.name).merge(style));
    }
  }
}
