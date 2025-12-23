import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';

enum FontType { google, system }

class Font {
  final String name;
  final FontType type;

  const Font({required this.name, required this.type});

  factory Font.fromJson(Map<String, dynamic> json) {
    return Font(
      name: json['name'] as String,
      type: FontType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => FontType.system,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'type': type.toString().split('.').last};
  }

  Future<TextStyle> toTextStyle() async {
    switch (type) {
      case FontType.system:
        return TextStyle(fontFamily: await SystemFonts().loadFont(name));
      case FontType.google:
        return GoogleFonts.getFont(name);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Font && other.name == name && other.type == type;
  }

  @override
  int get hashCode => name.hashCode ^ type.hashCode;
}
