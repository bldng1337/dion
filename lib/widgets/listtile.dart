import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionListTile extends StatelessWidget {
  final Function()? onTap;
  final Function()? onLongTap;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool isDense;
  final VisualDensity? visualDensity;
  final Color? textColor;
  final bool? selected;
  final bool? disabled;
  const DionListTile({
    super.key,
    this.disabled,
    this.onTap,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.isDense = false,
    this.visualDensity,
    this.textColor,
    this.onLongTap,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => ListTile(
          enabled: !(disabled ?? false),
          selected: selected ?? false,
          selectedTileColor: context.theme.highlightColor.withAlpha(20),
          onLongPress: onLongTap,
          onTap: onTap,
          textColor: textColor,
          isThreeLine: isThreeLine,
          dense: isDense,
          visualDensity: visualDensity,
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          minVerticalPadding: 4,
          minLeadingWidth: 40,
        ),
      DionThemeMode.cupertino => CupertinoListTile(
          onTap: onTap,
          leading: leading,
          trailing: trailing,
          title: title ?? nil,
          subtitle: subtitle,
        ),
    };
  }
}
