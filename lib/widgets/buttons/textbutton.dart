import 'dart:async';

import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionTextbutton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final ButtonStyle? style;
  final Widget child;
  const DionTextbutton({
    super.key,
    this.onPressed,
    required this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
        loading: TextButton(
          style: style,
          onPressed: null,
          child: const Center(child: CircularProgressIndicator()),
        ),
        builder: (context, _, setFuture) => TextButton(
          style: style,
          onPressed: () {
            setFuture(onPressed?.call());
          },
          child: child,
        ),
      ),
      DionThemeMode.cupertino => CupertinoButton(
        onPressed: onPressed,
        child: child,
      ),
    };
  }
}
