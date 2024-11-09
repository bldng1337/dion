import 'package:flutter/material.dart';

enum DionThemeMode {
  material,
}

class DionTheme {
  final DionThemeMode mode;
  final Brightness brightness;

  const DionTheme({required this.mode, required this.brightness});

  @override
  bool operator ==(Object other) {
    return other is DionTheme && other.mode == mode && other.brightness == brightness;
  }

  @override
  int get hashCode => Object.hash(mode, brightness);

  static const DionTheme material = DionTheme(mode: DionThemeMode.material, brightness: Brightness.light);

  static DionTheme of(BuildContext context) {
    final DionTheme? theme = context.dependOnInheritedWidgetOfExactType<InheritedDionTheme>()?.theme;
    return theme ?? DionTheme.material;
  }
}


class InheritedDionTheme extends InheritedWidget {
  final DionTheme theme;
  const InheritedDionTheme({required DionTheme theme, required super.child}) : theme = theme;

  @override
  bool updateShouldNotify(InheritedDionTheme oldWidget) {
    return theme != oldWidget.theme;
  }
}

extension DionThemeExt on BuildContext {
  DionTheme get diontheme => DionTheme.of(this);
}
