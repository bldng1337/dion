import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionPopupMenuItem {
  final Widget label;
  final IconData? icon;
  final Function()? onTap;
  const DionPopupMenuItem({required this.label, this.onTap, this.icon});
}

class DionPopupMenu extends StatelessWidget {
  final Widget child;
  final List<DionPopupMenuItem> items;
  const DionPopupMenu({super.key, required this.child, required this.items});

  void _showCupertinoMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: items
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  item.onTap?.call();
                },
                child: item.label,
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showDrawerMenu(BuildContext context) {
    showDionMenuDrawer(
      context: context,
      items: [
        for (final item in items)
          DionDrawerItem(
            label: item.label,
            icon: item.icon,
            onTap: item.onTap == null ? null : () async => item.onTap!(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material =>
        isMobilePlatform
            ? GestureDetector(
                onTap: () => _showDrawerMenu(context),
                child: child,
              )
            : PopupMenuButton(
                itemBuilder: (context) => items
                    .map((e) => PopupMenuItem(onTap: e.onTap, child: e.label))
                    .toList(),
                child: child,
              ),
      DionThemeMode.cupertino => GestureDetector(
        onTap: () => _showCupertinoMenu(context),
        child: child,
      ),
    };
  }
}
