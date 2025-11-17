import 'package:flutter/material.dart';

enum DionThemeMode { material, cupertino }

class DionTheme {
  final DionThemeMode mode;
  final Brightness brightness;

  const DionTheme({required this.mode, required this.brightness});

  @override
  bool operator ==(Object other) {
    return other is DionTheme &&
        other.mode == mode &&
        other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(mode, brightness);

  static const DionTheme material = DionTheme(
    mode: DionThemeMode.material,
    brightness: Brightness.light,
  );
  static const DionTheme cupertino = DionTheme(
    mode: DionThemeMode.cupertino,
    brightness: Brightness.light,
  );

  static DionTheme of(BuildContext context) {
    final DionTheme? theme = context
        .dependOnInheritedWidgetOfExactType<InheritedDionTheme>()
        ?.theme;
    return theme ?? DionTheme.material;
  }
}

ThemeData getTheme(Brightness b) {
  const Color primary = Color(0xFF6BA368);
  // const Color lightshade = Color(0xFFF4F7F5);
  // const Color lightaccent = Color(0xFF808181);
  // const Color darkaccent = Color(0xFF796394);
  // const Color darkshade = Color.fromARGB(255, 40, 36, 40);
  // final Color shade = b == Brightness.dark ? darkshade : lightshade;
  // final Color accent = b == Brightness.dark ? darkaccent : lightaccent;
  final ColorScheme colorScheme =
      ColorScheme.fromSeed(brightness: b, seedColor: primary).copyWith(
        // primary: primary,
        // onPrimary: lightshade,
        // secondary: accent,
        // onSecondary: lightshade,
        // tertiary: accent,
        // onTertiary: lightshade,
        // surface: shade,
        // onSurface: ishade,
      );
  return ThemeData(
    colorScheme: colorScheme,
    appBarTheme: const AppBarTheme(backgroundColor: primary, elevation: 20),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.tertiary,
      foregroundColor: colorScheme.onTertiary,
    ),
  );
}

class InheritedDionTheme extends InheritedWidget {
  final DionTheme theme;
  const InheritedDionTheme({required this.theme, required super.child});

  @override
  bool updateShouldNotify(InheritedDionTheme oldWidget) {
    return theme != oldWidget.theme;
  }
}

extension DionThemeExt on BuildContext {
  DionTheme get diontheme => DionTheme.of(this);
}
