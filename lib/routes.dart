import 'dart:convert';

import 'package:dionysos/views/browse.dart';
import 'package:dionysos/views/detail.dart';
import 'package:dionysos/views/library.dart';
import 'package:dionysos/views/view.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final homedestinations = [
  Destination(ico: Icons.library_books, name: 'Library', path: '/library'),
  Destination(ico: Icons.local_activity, name: 'Activity', path: '/activity'),
  Destination(ico: Icons.search, name: 'Browse', path: '/browse'),
  Destination(ico: Icons.settings, name: 'Settings', path: '/browse'),
];

GoRouter getRoutes() => GoRouter(
      extraCodec: const MyExtraCodec(),
      debugLogDiagnostics: true,
      // navigatorKey: locate<GlobalKey<NavigatorState>>(),
      initialLocation: '/browse',
      routes: [
        GoRoute(
          path: '/browse',
          builder: (context, state) => const Browse(),
        ),
        GoRoute(path: '/view', builder: (context, state) => const ViewSource()),
        GoRoute(path: '/detail', builder: (context, state) => const Detail()),
        GoRoute(path: '/library', builder: (context, state) => const Library()),
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
