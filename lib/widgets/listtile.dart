import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionListTile extends StatelessWidget {
  final Function()? onTap;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool isDense;
  final VisualDensity? visualDensity;
  final TextStyle? titleTextStyle;
  final TextStyle? subtitleTextStyle;
  final TextStyle? leadingAndTrailingTextStyle;
  const DionListTile(
      {super.key,
      this.onTap,
      this.leading,
      this.title,
      this.subtitle,
      this.trailing,
      this.isThreeLine = false,
      this.isDense = false,
      this.visualDensity,
      this.titleTextStyle,
      this.subtitleTextStyle,
      this.leadingAndTrailingTextStyle});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => ListTile(
          isThreeLine: isThreeLine,
          dense: isDense,
          visualDensity: visualDensity,
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: trailing,
          onTap: onTap,
          minVerticalPadding: 4,
          minLeadingWidth: 40,
          titleTextStyle: titleTextStyle,
          subtitleTextStyle: subtitleTextStyle,
          leadingAndTrailingTextStyle: leadingAndTrailingTextStyle,
        ),
      DionThemeMode.cupertino => CupertinoListTile(
        onTap: onTap,
        leading: leading,
        trailing: trailing,
        title: title??nil,
        subtitle: subtitle,
      ),
    };
  }
}
