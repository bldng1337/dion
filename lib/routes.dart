import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions_dart.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/views/activity.dart';
import 'package:dionysos/views/browse/browse.dart';
import 'package:dionysos/views/browse/library.dart';
import 'package:dionysos/views/browse/search.dart';
import 'package:dionysos/views/custom_view.dart';
import 'package:dionysos/views/detail/detail.dart';
import 'package:dionysos/views/extension/extension_manager.dart';
import 'package:dionysos/views/extension/extension_view.dart';
import 'package:dionysos/views/loading.dart';
import 'package:dionysos/views/settings/audio_listener.dart';
import 'package:dionysos/views/settings/developer.dart';
import 'package:dionysos/views/settings/developer/log.dart';
import 'package:dionysos/views/settings/extension.dart';
import 'package:dionysos/views/settings/widget_playground.dart';
import 'package:dionysos/views/settings/imagelist_reader.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/views/settings/paragraph_reader.dart';
import 'package:dionysos/views/settings/settings.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:dionysos/views/settings/sync.dart';
import 'package:dionysos/views/settings/tasks.dart';
import 'package:dionysos/views/settings/update_settings.dart';
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

GoRouter getRoutes() => GoRouter(
  navigatorKey: navigatorKey,
  extraCodec: const MyExtraCodec(),
  debugLogDiagnostics: true,
  initialLocation: '/',
  // redirect: (context, state) {
  //   return null;
  // },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          getTransition(context, state, const LoadingView()),
    ),
    GoRoute(
      path: '/browse',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Browse()),
    ),
    GoRoute(
      path: '/activity',
      pageBuilder: (context, state) =>
          getTransition(context, state, const ActivityView()),
    ),
    GoRoute(
      path: '/manage',
      pageBuilder: (context, state) =>
          getTransition(context, state, const ExtensionManager()),
    ),
    GoRoute(
      path: '/search/:query',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Search()),
    ),
    GoRoute(
      path: '/extension/:id',
      pageBuilder: (context, state) =>
          getTransition(context, state, const ExtensionView()),
    ),
    GoRoute(
      path: '/view',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const ViewSource(),
        transition: Transition.fade,
      ),
    ),
    GoRoute(
      path: 'custom',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const CustomUiView(),
        transition: Transition.fade,
      ),
    ),
    GoRoute(
      path: '/detail',
      pageBuilder: (context, state) => getTransition(
        context,
        state,
        const Detail(),
        transition: Transition.fade,
      ),
    ),
    GoRoute(
      path: '/library',
      pageBuilder: (context, state) =>
          getTransition(context, state, const Library()),
    ),
    GoRoute(
      path: '/dev',
      pageBuilder: (context, state) =>
          getTransition(context, state, const DeveloperSettings()),
      routes: [
        GoRoute(
          path: '/logs',
          pageBuilder: (context, state) =>
              getTransition(context, state, const LogView()),
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
          getTransition(context, state, const Settings()),
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
          path: '/sync',
          pageBuilder: (context, state) =>
              getTransition(context, state, const SyncSettings()),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) =>
              getTransition(context, state, const LibrarySettings()),
        ),
        GoRoute(
          path: '/tasks',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ActiveTasksSettings()),
        ),
        GoRoute(
          path: '/extension',
          pageBuilder: (context, state) =>
              getTransition(context, state, const ExtensionSettings()),
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
}) => switch (transition) {
  Transition.fade => CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: 250.milliseconds,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
        child: child,
      );
    },
  ),
  Transition.none => NoTransitionPage<void>(key: state.pageKey, child: child),
};

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
    if (input == null) {
      return null;
    }
    // final List<Object?> inputAsList = input as List<Object?>;
    // if (inputAsList[0] == 'ComplexData1') {
    //   return ComplexData1(inputAsList[1]! as String);
    // }
    // if (inputAsList[0] == 'ComplexData2') {
    //   return ComplexData2(inputAsList[1]! as String);
    // }
    throw FormatException('Unable to parse input: $input');
  }
}

class _MyExtraEncoder extends Converter<Object?, Object?> {
  const _MyExtraEncoder();
  @override
  Object? convert(Object? input) {
    if (input == null) {
      return null;
    }
    return 'SomeData';
    // switch (input) {
    //   case ComplexData1 _:
    //     return <Object?>['ComplexData1', input.data];
    //   case ComplexData2 _:
    //     return <Object?>['ComplexData2', input.data];
    //   default:
    //     throw FormatException('Cannot encode type ${input.runtimeType}');
    // }
  }
}
