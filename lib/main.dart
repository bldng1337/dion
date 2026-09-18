import 'dart:io';

import 'package:dionysos/routes.dart';
import 'package:dionysos/service/periodic_service.dart';
import 'package:dionysos/utils/crashlytics.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workmanager/workmanager.dart';

// ignore: unreachable_from_main
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

GoRouter? appRouter;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initCrashlytics();
  FlutterError.onError = (details) {
    logger.e(
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  // Uncaught async errors do not force-close the app; route them into the
  // log store so users can report them at their own discretion.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    logger.e('Uncaught error', error: error, stackTrace: stack);
    return true;
  };
  if (!Platform.isWindows) {
    await Workmanager().initialize(backgroundTaskDispatcher);
  }
  final route = getRoutes();
  appRouter = route;
  initApp(route: route);
}

void initApp({required RouterConfig<Object> route}) {
  const theme = DionTheme.material;
  runApp(
    InheritedDionTheme(
      theme: theme,
      child: switch (theme.mode) {
        DionThemeMode.material => MaterialApp.router(
          title: 'dion',
          theme: getTheme(theme.brightness),
          routerConfig: route,
          scaffoldMessengerKey: scaffoldMessengerKey,
        ),
        DionThemeMode.cupertino => CupertinoApp.router(
          title: 'dion',
          theme: MaterialBasedCupertinoThemeData(
            materialTheme: getTheme(theme.brightness),
          ),
          routerConfig: route,
        ),
      },
    ),
  );
}
