import 'package:dionysos/routes.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/views/app_loader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initApp(
    app: () => AppLoader(
      tasks: [
        () async {
          await Database.ensureInitialized();
        },
        () async {
          await PreferenceService.ensureInitialized();
        },
        () async {
          await SourceExtension.ensureInitialized();
        },
        () async {
          await DirectoryProvider.ensureInitialized();
        },
        () async {
          await CacheService.ensureInitialized();
        },
        () async {
          MediaKit.ensureInitialized();
        },
        () async {
          await NetworkService.ensureInitialized();
        },
        () async {
          await checkVersion();
        },
      ],
      onComplete: (context) {
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
    InheritedDionTheme(
      theme: theme,
      child: switch (theme.mode) {
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
                navigatorKey: navigatorKey,
              ),
        DionThemeMode.cupertino => isrouter
            ? CupertinoApp.router(
                theme: MaterialBasedCupertinoThemeData(
                  materialTheme: getTheme(theme.brightness),
                ),
                routerConfig: route,
              )
            : CupertinoApp(
                theme: MaterialBasedCupertinoThemeData(
                  materialTheme: getTheme(theme.brightness),
                ),
                home: app!(),
                navigatorKey: navigatorKey,
              ),
      },
    ),
  );
}
