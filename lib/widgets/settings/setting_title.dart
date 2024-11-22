import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';

class SettingTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget>? children;
  const SettingTitle(
      {super.key, required this.title, this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: icon != null ? Icon(icon) : null,
          title: Text(
            title,
            style: context.titleLarge,
          ),
        ),
        if (children != null) Column(children: children!).paddingOnly(left: 15),
      ],
    );
  }
}
