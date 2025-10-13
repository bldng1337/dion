import 'package:dionysos/routes.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    logger.e(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  initApp(route: getRoutes());
}

void initApp({required RouterConfig<Object> route}) {
  const theme = DionTheme.material;
  runApp(
    InheritedDionTheme(
      theme: theme,
      child: switch (theme.mode) {
        DionThemeMode.material => MaterialApp.router(
          theme: getTheme(theme.brightness),
          // darkTheme: getTheme(Brightness.dark),
          routerConfig: route,
        ),
        DionThemeMode.cupertino => CupertinoApp.router(
          theme: MaterialBasedCupertinoThemeData(
            materialTheme: getTheme(theme.brightness),
          ),
          routerConfig: route,
        ),
      },
    ),
  );
}
