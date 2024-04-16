import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoadingScreen extends StatelessWidget {
  final Future<Widget?> loader;

  const LoadingScreen(this.loader, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder(
        future: loader,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data == null) {
              Future.microtask(() => context.pop(),);
              return Container();
            }
            Future.microtask(() => context.pushReplacement("/any", extra: snapshot.data!),);
            // ;
            return Container();
          }
          if (snapshot.hasError) {
            return ErrorWidget(snapshot.error!);
          }
          return const Center(child: CircularProgressIndicator(),);
        },
      ),
    );
  }
}
