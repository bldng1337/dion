import 'package:dionysos/views/browse.dart';
import 'package:dionysos/views/detail.dart';
import 'package:dionysos/views/view.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final homedestinations = [
  Destination(ico: Icons.home, name: 'Home', path: '/'),
  Destination(ico: Icons.search, name: 'Search', path: '/search'),
  Destination(ico: Icons.settings, name: 'Settings', path: '/settings'),
  Destination(ico: Icons.help, name: 'Help', path: '/help'),
];

GoRouter getRoutes() => GoRouter(
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
      ],
    );
