import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';

class Loadable extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    Widget child,
    Function(FutureOr<void> future),
  ) builder;
  final Widget? loading;
  final Widget? child;
  const Loadable({super.key, this.child, this.loading, required this.builder});

  @override
  State<Loadable> createState() => _LoadableState();
}

class _LoadableState extends State<Loadable> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loading ?? const Center(child: CircularProgressIndicator());
    }
    return widget.builder(
      context,
      widget.child ?? nil,
      (future) {
        if (future is! Future) {
          return;
        }
        _loading = true;
        Future.delayed(100.milliseconds).then((_) {
          //Delay rerendering to prevent flickering on short loading times
          if (!mounted) return;
          setState(() {});
        });
        future.then(
          (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
          onError: (e) {
            logger.e('Error loading future', error: e);
            setState(() {
              _loading = false;
            });
          },
        );
      },
    );
  }
}
