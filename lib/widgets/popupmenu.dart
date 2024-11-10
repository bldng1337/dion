import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionPopupMenuItem {
  final Widget label;
  final Function()? onTap;
  const DionPopupMenuItem({required this.label, this.onTap});
}

class DionPopupMenu extends StatelessWidget {
  final Widget child;
  final List<DionPopupMenuItem> items;
  const DionPopupMenu({super.key, required this.child, required this.items});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => PopupMenuButton(
          itemBuilder: (context) => items
              .map(
                (e) => PopupMenuItem(
                  onTap: e.onTap,
                  child: e.label,
                ),
              )
              .toList(),
          child: child,
        ),
      DionThemeMode.cupertino => CupertinoPopupSurface(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items
                  .map(
                    (e) => CupertinoButton(
                      onPressed: e.onTap,
                      child: e.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
    };
  }
}
