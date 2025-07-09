import 'dart:async';

import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionIconbutton extends StatelessWidget {
  final String? tooltip;
  final FutureOr<void> Function()? onPressed;
  final Widget? icon;
  const DionIconbutton({super.key, this.onPressed, this.icon, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Loadable(
          loading: const IconButton(
            onPressed: null,
            icon: CircularProgressIndicator(),
          ),
          builder: (context, _, setFuture) => IconButton(
            icon: icon ?? const Icon(Icons.question_mark),
            tooltip: tooltip,
            onPressed: () {
              setFuture(onPressed?.call());
            },
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      DionThemeMode.cupertino => CupertinoButton(
          onPressed: onPressed,
          child: icon ?? const Icon(Icons.question_mark),
        ),
    };
  }
}
