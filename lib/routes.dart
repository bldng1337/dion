import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/views/browse.dart';
import 'package:dionysos/views/detail.dart';
import 'package:dionysos/views/extension_manager.dart';
import 'package:dionysos/views/library.dart';
import 'package:dionysos/views/search.dart';
import 'package:dionysos/views/settings/imagelist_reader.dart';
import 'package:dionysos/views/settings/paragraph_reader.dart';
import 'package:dionysos/views/settings/settings.dart';
import 'package:dionysos/views/settings/sync.dart';
import 'package:dionysos/views/view.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final homedestinations = [
  Destination(ico: Icons.bookmark, name: 'Library', path: '/library'),
  Destination(ico: Icons.update, name: 'Activity', path: '/activity'),
  Destination(ico: Icons.search, name: 'Browse', path: '/browse'),
  Destination(ico: Icons.extension, name: 'Manage Extensions', path: '/manage'),
  Destination(ico: Icons.settings, name: 'Settings', path: '/settings'),
];

GoRouter getRoutes() => GoRouter(
      extraCodec: const MyExtraCodec(),
      debugLogDiagnostics: true,
      // navigatorKey: locate<GlobalKey<NavigatorState>>(),
      initialLocation: '/library',
      redirect: (context, state) {
        if (state.fullPath == '/') {
          context.go('/library');
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            context.go('/browse');
            return nil;
          },
        ),
        GoRoute(
          path: '/browse',
          builder: (context, state) => const Browse(),
        ),
        GoRoute(
            path: '/manage',
            builder: (context, state) => const ExtensionManager()),
        GoRoute(
          path: '/search/:query',
          builder: (context, state) => const Search(),
        ),
        GoRoute(path: '/view', builder: (context, state) => const ViewSource()),
        GoRoute(path: '/detail', builder: (context, state) => const Detail()),
        GoRoute(path: '/library', builder: (context, state) => const Library()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Settings(),
          routes: [
            GoRoute(
              path: '/paragraphreader',
              builder: (context, state) => const ParagraphReaderSettings(),
            ),
            GoRoute(
              path: '/imagelistreader',
              builder: (context, state) => const ImageListReaderSettings(),
            ),
            GoRoute(
              path: '/sync',
              builder: (context, state) => const SyncSettings(),
            ),
          ],
        ),
      ],
    );

class MyExtraCodec extends Codec<Object?, Object?> {
  /// Create a codec.
  const MyExtraCodec();
  @override
  Converter<Object?, Object?> get decoder => const _MyExtraDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _MyExtraEncoder();
}

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
