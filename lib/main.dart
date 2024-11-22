import 'package:dionysos/routes.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/preference.dart';
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
              ),
        DionThemeMode.cupertino => isrouter
            ? CupertinoApp.router(
                theme: MaterialBasedCupertinoThemeData(
                    materialTheme: getTheme(theme.brightness)),
                routerConfig: route,
              )
            : CupertinoApp(
                theme: MaterialBasedCupertinoThemeData(
                    materialTheme: getTheme(theme.brightness)),
                home: app!(),
              ),
      },
    ),
  );
}
