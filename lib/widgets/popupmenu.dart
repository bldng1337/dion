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
    return PopupMenuButton(
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem(
              onTap: e.onTap,
              child: e.label,
            ),
          )
          .toList(),
      child: child,
    );
  }
}
