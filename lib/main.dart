import 'package:dionysos/routes.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/views/app_loader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rhttp/rhttp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  register(GlobalKey<NavigatorState>());
  initApp(
    app: () => AppLoader(
      tasks: [
        (context) async {
          await SourceExtension.ensureInitialized();
        },
        (context) async {
          await DirectoryProvider.ensureInitialized();
        },
        (context) async {
          await Rhttp.init();
          await CacheService.ensureInitialized();
        },
      ],
      onComplete: (context) {
        register(GlobalKey<NavigatorState>());
        initApp(route: getRoutes());
      },
    ),
  );
}

void initApp({
  Widget Function()? app,
  RouterConfig<Object>? route,
}) {
  const theme = DionTheme.material;
  final isrouter = route != null;
  runApp(
    switch (theme.mode) {
      DionThemeMode.material => isrouter
          ? MaterialApp.router(
              theme: getTheme(theme.brightness),
              darkTheme: getTheme(Brightness.dark),
              routerConfig: route,
            )
          : MaterialApp(
              theme: getTheme(theme.brightness),
              darkTheme: getTheme(Brightness.dark),
              home: app!(),
            )
    },
  );
}

ThemeData getTheme(Brightness b) {
  const Color primary = Color(0xFF6BA368);
  const Color lightshade = Color(0xFFF4F7F5);
  const Color lightaccent = Color(0xFF808181);
  const Color darkaccent = Color(0xFF796394);
  const Color darkshade = Color.fromARGB(255, 40, 36, 40);
  final Color shade = b == Brightness.dark ? darkshade : lightshade;
  final Color ishade = b == Brightness.light ? darkshade : lightshade;
  final Color accent = b == Brightness.dark ? darkaccent : lightaccent;
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    brightness: b,
    seedColor: primary,
  ).copyWith(
    primary: primary,
    onPrimary: lightshade,
    secondary: accent,
    onSecondary: lightshade,
    tertiary: accent,
    onTertiary: lightshade,
    surface: shade,
    onSurface: ishade,
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
