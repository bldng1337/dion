import 'dart:async';

import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final Widget? child;
  final FutureOr<void> Function()? onPressed;
  const ActionButton({super.key, this.onPressed, this.child});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
          loading: const FloatingActionButton(
            onPressed: null,
            child: Center(child: CircularProgressIndicator()),
          ),
          builder: (context, _, setFuture) => FloatingActionButton(
            onPressed: () {
              setFuture(onPressed?.call());
            },
            child: child,
          ),
        ),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}
