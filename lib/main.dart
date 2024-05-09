import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/sync.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/update.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/views/activityview.dart';
import 'package:dionysos/views/detailedentryview.dart';
import 'package:dionysos/views/entrybrowseview.dart';
import 'package:dionysos/views/extensionsettingview.dart';
import 'package:dionysos/views/extensionview.dart';
import 'package:dionysos/views/libraryview.dart';
import 'package:dionysos/views/loadingscreenview.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nanoid/nanoid.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final SharedPreferences prefs;
late final Isar isar;
late String deviceId;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) exit(1);
  };
  return runApp(
    const MaterialApp(
      home: AppLoader(),
    ),
  );
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class LoadTask {
  final Future<void> Function(BuildContext context) task;
  final String name;
  LoadTask(this.task, this.name);
}

class _AppLoaderState extends State<AppLoader> {
  List<LoadTask> tasks = [
    LoadTask(
      (context) async {
        prefs = await SharedPreferences.getInstance();
      },
      'Shared Preferences',
    ),
    LoadTask(
      (context) async {
        final update = await checkUpdate();
        if (context.mounted &&
            update != null &&
            !hasNotifiedForUpdate(update.version)) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    child: const Text('Dont Update')),
                TextButton(
                    onPressed: () {
                      
                      showDialog(
                          context: context,
                          builder: (context) => UpdatingDialog(update: update,),);
                    },
                    child: const Text('Update')),
              ],
              title: const Text(
                'New Version available!',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Current version ${update.currentversion}'),
                  Text('Update to version ${update.version}'),
                  const Text('Notes:'),
                  Text(update.body),
                ],
              ),
            ),
          );
        }
      },
      'Checking for Updates',
    ),
    LoadTask(
      (context) async {
        await ensureJSBridgeInitialised();
      },
      'JS Extensions',
    ),
    LoadTask(
      (context) async {
        final isardb =
            (await getPath('data')).getFile('${Isar.defaultName}.isar');
        if (!(await isardb.exists())) {
          prefs.setString('deviceid', nanoid());
        }
        deviceId = prefs.getString('deviceid') ?? nanoid();
        prefs.setString('deviceid', deviceId);
      },
      'Device ID',
    ),
    LoadTask(
      (context) async {
        await ExtensionManager().finit;
      },
      'ExtensionManager',
    ),
    LoadTask(
      (context) async {
        await FileDownloader().trackTasks();
        await FileDownloader()
            .cancelTasksWithIds(await FileDownloader().allTaskIds());
        if (kDebugMode) {
          FileDownloader().updates.listen((update) {
            switch (update) {
              case TaskStatusUpdate _:
                // process the TaskStatusUpdate, e.g.
                switch (update.status) {
                  case TaskStatus.complete:
                    // ignore: avoid_print
                    print('Task ${update.task.displayName} success!');
                  case TaskStatus.canceled:
                    // ignore: avoid_print
                    print('Download was canceled');
                  case TaskStatus.paused:
                    // ignore: avoid_print
                    print('Download was paused');
                  default:
                    // ignore: avoid_print
                    print('Download not successful');
                }
              case TaskProgressUpdate _:
                // ignore: avoid_print
                print('${update.task.displayName} ${update.progress}');
            }
          });
        }
      },
      'Downloader',
    ),
    LoadTask(
      (context) async {
        isar = await Isar.open(
          [EntrySavedSchema, ActivitySchema, CategorySchema],
          directory: (await getPath('data')).path,
          // inspector: true,
          compactOnLaunch: const CompactCondition(minBytes: 100 * 1000000),
        );
      },
      'Library',
    ),
    LoadTask(
      (context) async {
        await dosync();
      },
      'Starting Sync',
    ),
    LoadTask(
      (context) async {
        final int now = DateTime.now().day;
        if (now != (prefs.getInt('lasttime') ?? 32)) {
          await prefs.setInt('lasttime', now);
          updateEntries();
        }
      },
      'Library Update',
    ),
  ];
  int progress = 0;
  late Future<void> current;
  @override
  void initState() {
    super.initState();
    current = tasks[progress].task(context);
  }

  Future<void> update() async {
    if (progress + 1 >= tasks.length) {
      runApp(const MyApp());
    } else {
      setState(() {
        current = tasks[++progress].task(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: current,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          try {
            final Error e = snapshot.error! as Error;
            return ErrorScreen(
              e,
              actions: [
                LoadTask(
                  (context) async {
                    final isardb = (await getPath('data'))
                        .getFile('${Isar.defaultName}.isar');
                    final isardblock = (await getPath('data'))
                        .getFile('${Isar.defaultName}.isar');
                    Isar.getInstance()?.close();
                    if (await isardblock.exists()) {
                      await isardblock.delete();
                    }
                    if (await isardb.exists()) {
                      await isardb.delete();
                    }
                    await prefs.clear();
                    Restart.restartApp();
                  },
                  'Delete Data',
                ),
                LoadTask(
                  (context) async {
                    Restart.restartApp();
                  },
                  'Retry',
                ),
              ],
            );
          } catch (e) {
            return ErrorWidget(e);
          }
        }
        if (snapshot.connectionState == ConnectionState.done) {
          Future.microtask(update);
        }
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                    padding: EdgeInsets.all(25),
                    child: Image(
                      image: AssetImage('assets/icon/icon.png'),
                      height: 130,
                    ),),
                const CircularProgressIndicator(),
                Text(
                  'Loading ${tasks[progress].name} $progress/${tasks.length}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final Error e;
  final List<LoadTask>? actions;
  const ErrorScreen(this.e, {super.key, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              color: Colors.red,
            ),
            Text(
              'Encountered Error:\n$e',
              textAlign: TextAlign.center,
            ),
            if (e.stackTrace != null) Text(e.stackTrace.toString()),
            if (actions != null)
              Row(
                children: actions!
                    .map(
                      (e) => Expanded(
                        child: TextButton(
                            onPressed: () => e.task(context),
                            child: Text(e.name)),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> updateEntries() async {
  for (int i = 0; i < await isar.entrySaveds.count(); i++) {
    final entry = await isar.entrySaveds.get(i);
    if (entry == null) {
      continue;
    }
    if (entry.getlastReadIndex() + 1 == entry.totalepisodes) {
      await entry.refresh();
    }
  }
}

class Nav extends StatelessWidget {
  final Widget child;
  final Widget? bottom;
  final List<Widget>? actions;
  const Nav({super.key, required this.child, this.bottom, this.actions});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      bottom: bottom,
      actions: actions,
      destination: [
        Destination(ico: Icons.bookmark, name: 'Library', path: '/lib'),
        Destination(
          ico: Icons.local_activity,
          name: 'Activity',
          path: '/activity',
        ),
        Destination(ico: Icons.book_online, name: 'Browse', path: '/browseall'),
        Destination(
          ico: Icons.admin_panel_settings,
          name: 'Manage',
          path: '/manage',
        ),
        Destination(ico: Icons.settings, name: 'Settings', path: '/settings'),
      ],
      child: child,
    );
  }
}

class Redirect extends StatelessWidget {
  final String path;
  const Redirect({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(milliseconds: 100), () async {
      context.go(path);
    });
    return const Center(child: CircularProgressIndicator());
  }
}

final _router = GoRouter(
  initialLocation: '/lib',
  routes: [
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const Redirect(path: '/browseall');
      },
    ), //LoadingScreen
    GoRoute(
      path: '/load',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child:
            LoadingScreen(GoRouterState.of(context).extra! as Future<Widget?>),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/any',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const Any(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/entryview',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const EntryDetailedView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/manage/extensionsettings',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: Extensionsetting(state.extra! as Extension),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return child;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const ActivityScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/browseall',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const EntryBrowseView(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: Nav(child: settingspage.barebuild(null)),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/lib',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const Library(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/manage',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            child: const Extensionview(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
      ],
    ),
  ],
);

class Destination {
  final IconData ico;
  final String name;
  final String path;
  Destination({required this.ico, required this.name, required this.path});
}

class NavScaff extends StatelessWidget {
  final Widget child;
  final List<Destination> destination;
  final Widget? bottom;
  final List<Widget>? actions;
  const NavScaff({
    super.key,
    required this.child,
    required this.destination,
    this.bottom,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final int index = destination.indexWhere(
      (element) =>
          GoRouterState.of(context).fullPath?.startsWith(element.path) ?? false,
    );

    if (isVertical(context)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(index >= 0 ? destination[index].name : ''),
          actions: actions,
        ),
        body: child,
        bottomSheet: bottom,
        bottomNavigationBar: NavigationBar(
          destinations: destination
              .map(
                (e) => NavigationDestination(
                  icon: Icon(e.ico),
                  label: e.name,
                ),
              )
              .toList(),
          onDestinationSelected: (i) => context.go(destination[i].path),
          selectedIndex: index >= 0 ? index : 0,
        ),
      );
    }
    final Widget navrail = NavigationRail(
      backgroundColor: Theme.of(context).highlightColor,
      onDestinationSelected: (i) => context.go(destination[i].path),
      labelType: NavigationRailLabelType.all,
      destinations: destination
          .map(
            (e) => NavigationRailDestination(
              icon: Icon(e.ico),
              label: Text(e.name),
            ),
          )
          .toList(),
      selectedIndex: index >= 0 ? index : null,
    );
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraint) {
              return ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraint.maxHeight),
                    child: IntrinsicHeight(
                      child: navrail,
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(child: child),
        ],
      ),
      bottomSheet: bottom,
      appBar: AppBar(
        title: Text(index >= 0 ? destination[index].name : ''),
        actions: actions,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: getTheme(context),
      routerConfig: _router,
    );
  }
}

ThemeData getTheme(BuildContext context) {
  const Color primary = Color(0xFF6BA368);
  const Color lightshade = Color(0xFFF4F7F5);
  const Color lightaccent = Color(0xFF808181);
  const Color darkaccent = Color(0xFF796394);
  const Color darkshade = Color.fromARGB(255, 40, 36, 40);
  final Brightness b = MediaQuery.platformBrightnessOf(context);
  final Color shade = b == Brightness.dark ? darkshade : lightshade;
  final Color ishade = b == Brightness.light ? darkshade : lightshade;
  final Color accent = b == Brightness.dark ? darkaccent : lightaccent;
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    brightness: b,
    seedColor: primary,
  ).copyWith(
    primary: primary,
    onPrimary: lightshade,
    background: shade,
    onBackground: ishade,
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
