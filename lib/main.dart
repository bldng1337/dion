import 'package:dionysos/views/app_loader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_extended_platform_widgets/flutter_extended_platform_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    AppLoader(
      tasks: List.generate(
        10,
        (index) => LoadTask(
          (context) async {
            await Future.delayed(Duration(seconds: index + 1));
          },
          "Task $index",
        ),
      ),
      onComplete: (context) {
        print("Completed");
      },
    ),
  );
}

void initApp({Widget Function()? app, RouterConfig<Object>? route}) {
  runApp(
    PlatformProvider(
      builder: (context) {
        final materialLightTheme = getTheme(Brightness.light);
        final materialDarkTheme = getTheme(Brightness.dark);
        final cupertinoDarkTheme =
            MaterialBasedCupertinoThemeData(materialTheme: materialDarkTheme);
        final cupertinoLightTheme =
            MaterialBasedCupertinoThemeData(materialTheme: materialLightTheme);
        return PlatformTheme(
          themeMode: ThemeMode.system,
          materialLightTheme: materialLightTheme,
          materialDarkTheme: materialDarkTheme,
          cupertinoLightTheme: cupertinoLightTheme,
          cupertinoDarkTheme: cupertinoDarkTheme,
          builder: (context) {
            if (route != null) {
              return PlatformApp.router(
                localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                  DefaultMaterialLocalizations.delegate,
                  DefaultWidgetsLocalizations.delegate,
                  DefaultCupertinoLocalizations.delegate,
                ],
                title: 'Dion',
                routerConfig: route,
              );
            }
            return PlatformApp(
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
              ],
              title: 'Loading...',
              home: app!(),
            );
          },
        );
      },
    ),
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
