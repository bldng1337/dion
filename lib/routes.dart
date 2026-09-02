import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions_dart.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/views/activity.dart';
import 'package:dionysos/views/browse/browse.dart';
import 'package:dionysos/views/browse/library.dart';
import 'package:dionysos/views/browse/search.dart';
import 'package:dionysos/views/custom_view.dart';
import 'package:dionysos/views/detail/detail.dart';
import 'package:dionysos/views/detail/saved_quotes.dart';
import 'package:dionysos/views/dialog/migrate.dart';
import 'package:dionysos/views/extension/extension_manager.dart';
import 'package:dionysos/views/extension/extension_view.dart';
import 'package:dionysos/views/loading.dart';
import 'package:dionysos/views/settings/about.dart';
import 'package:dionysos/views/settings/audio_listener.dart';
import 'package:dionysos/views/settings/developer.dart';
import 'package:dionysos/views/settings/developer/log.dart';
import 'package:dionysos/views/settings/developer/query.dart';
import 'package:dionysos/views/settings/devices.dart';
import 'package:dionysos/views/settings/extension.dart';
import 'package:dionysos/views/settings/imagelist_reader.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/views/settings/paragraph_reader.dart';
import 'package:dionysos/views/settings/periodic_jobs.dart';
import 'package:dionysos/views/settings/settings.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:dionysos/views/settings/sync.dart';
import 'package:dionysos/views/settings/tasks.dart';
import 'package:dionysos/views/settings/update_settings.dart';
import 'package:dionysos/views/settings/videoplayer.dart';
import 'package:dionysos/views/settings/widget_playground.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final homedestinations = [
  Destination(ico: Icons.bookmark, name: 'Library', path: '/library'),
  Destination(ico: Icons.update, name: 'Activity', path: '/activity'),
  Destination(ico: Icons.search, name: 'Browse', path: '/browse'),
  Destination(ico: Icons.extension, name: 'Extensions', path: '/manage'),
  Destination(ico: Icons.settings, name: 'Settings', path: '/settings'),
];

GoRouter getRoutes({String initialLocation = '/'}) => GoRouter(
  navigatorKey: navigatorKey,
  extraCodec: const MyExtraCodec(),
  debugLogDiagnostics: true,
  initialLocation: initialLocation,
  // redirect: (context, state) {
  //   return null;
  // },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          getTransition(context, state, const LoadingView(), title: 'Loading'),
    ),
    GoRoute(
      path: '/browse',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Browse(), title: 'Browse'),
    ),
    GoRoute(
      path: '/activity',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const ActivityView(),
        title: 'Activity',
      ),
    ),
    GoRoute(
      path: '/manage',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const ExtensionManager(),
        title: 'Extensions',
      ),
    ),
    GoRoute(
      path: '/search/:query',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const Search(),
        title: 'Search ${state.pathParameters['query'] ?? ''}'.trim(),
      ),
    ),
    GoRoute(
      path: '/extension/:id',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const ExtensionView(),
        title: 'Extension',
      ),
    ),
    GoRoute(
      path: '/view',
      pageBuilder: (context, state) {
        // Announce the episode/chapter name to screen readers instead of a
        // generic page label. The reader is opened with [EpisodePath] extra.
        final extra = state.extra;
        final episodePath = extra is List<Object?> && extra.first is EpisodePath
            ? extra.first! as EpisodePath
            : null;
        return getTransition(
          context,
          state,
          const ViewSource(),
          transition: Transition.fade,
          title: episodePath?.name ?? 'Viewer',
        );
      },
    ),
    GoRoute(
      path: 'custom',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const CustomUiView(),
        transition: Transition.fade,
        title: 'Viewer',
      ),
    ),
    GoRoute(
      path: '/detail',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const Detail(),
        transition: Transition.fade,
        title: 'Details',
      ),
    ),
    GoRoute(
      path: '/quotes',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        SavedQuotesView(
          entry: (state.extra! as List<Object?>)[0]! as EntrySaved,
        ),
        transition: Transition.fade,
        title: 'Saved Quotes',
      ),
    ),
    GoRoute(
      path: '/migrate',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const MigrateEntryPage(),
        transition: Transition.fade,
        title: 'Migrate',
      ),
    ),
    GoRoute(
      path: '/library',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Library(), title: 'Library'),
    ),
    GoRoute(
      path: '/dev',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const DeveloperSettings(),
        title: 'Developer',
      ),
      routes: [
        GoRoute(
          path: '/logs',
          pageBuilder: (context, state) =>
              getTransition(context, state, const LogView()),
        ),
        GoRoute(
          path: '/query',
          pageBuilder: (context, state) =>
              getTransition(context, state, const QueryDebugger()),
        ),
        GoRoute(
          path: '/widgets',
          pageBuilder: (context, state) =>
              getTransition(context, state, const WidgetPlayground()),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Settings(), title: 'Settings'),
      routes: [
        GoRoute(
          path: '/update',
          pageBuilder: (context, state) =>
              getTransition(context, state, const UpdateSettings()),
        ),
        GoRoute(
          path: '/paragraphreader',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ParagraphReaderSettings()),
        ),
        GoRoute(
          path: '/audiolistener',
          pageBuilder: (context, state) =>
              getTransition(context, state, const AudioListenerSettings()),
        ),
        GoRoute(
          path: '/storage',
          pageBuilder: (context, state) =>
              getTransition(context, state, const Storage()),
        ),
        GoRoute(
          path: '/imagelistreader',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ImageListReaderSettings()),
        ),
        GoRoute(
          path: '/videoplayer',
          pageBuilder: (context, state) =>
              getTransition(context, state, const VideoPlayerSettings()),
        ),
        GoRoute(
          path: '/sync',
          pageBuilder: (context, state) =>
              getTransition(context, state, const SyncSettings()),
        ),
        GoRoute(
          path: '/devices',
          pageBuilder: (context, state) =>
              getTransition(context, state, const DevicesSettings()),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) => getTransition(
            context,
            state,
            const LibrarySettings(),
            title: 'Library',
          ),
        ),
        GoRoute(
          path: '/tasks',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ActiveTasksSettings()),
        ),
        GoRoute(
          path: '/periodicjobs',
          pageBuilder: (context, state) =>
              getTransition(context, state, const PeriodicJobsSettings()),
        ),
        GoRoute(
          path: '/extension',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ExtensionSettings()),
        ),
        GoRoute(
          path: '/about',
          pageBuilder: (context, state) =>
              getTransition(context, state, const AboutSettings()),
        ),
      ],
    ),
  ],
);

Page getTransition(
  BuildContext context,
  GoRouterState state,
  Widget child, {
  Transition transition = Transition.none,
  String? title,
}) {
  // Announce the page name to screen readers when the route is shown.
  final effectiveChild = title == null
      ? child
      : Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: child,
        );
  return switch (transition) {
    Transition.fade => CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: 250.milliseconds,
      child: effectiveChild,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
          child: child,
        );
      },
    ),
    Transition.none => NoTransitionPage<void>(
      key: state.pageKey,
      child: effectiveChild,
    ),
  };
}

class MyExtraCodec extends Codec<Object?, Object?> {
  /// Create a codec.
  const MyExtraCodec();
  @override
  Converter<Object?, Object?> get decoder => const _MyExtraDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _MyExtraEncoder();
}

enum Transition { fade, none }

class _MyExtraDecoder extends Converter<Object?, Object?> {
  const _MyExtraDecoder();
  @override
  Object? convert(Object? input) {
    return null;
  }
}

class _MyExtraEncoder extends Converter<Object?, Object?> {
  const _MyExtraEncoder();
  @override
  Object? convert(Object? input) {
    return input;
  }
}
