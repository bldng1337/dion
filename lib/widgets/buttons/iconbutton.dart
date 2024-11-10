import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/dynamic_grid.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionIconbutton extends StatelessWidget {
  final String? tooltip;
  final Function()? onPressed;
  final Widget? icon;
  const DionIconbutton({super.key, this.onPressed, this.icon, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => IconButton(
          icon: icon ?? const Icon(Icons.question_mark),
          tooltip: tooltip,
          onPressed: onPressed,
          style: const ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      DionThemeMode.cupertino => CupertinoButton(
          onPressed: onPressed,
          child: icon ?? const Icon(Icons.question_mark),
        ),
    };
  }
}
