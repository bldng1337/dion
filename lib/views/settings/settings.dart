import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/routes.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Settings'),
      destination: homedestinations,
      child: ListView(
        children: [
          SettingTitle(
            title: 'Reader Settings',
            children: [
              ListTile(
                title: Text(
                  'Paragraph Reader',
                  style: context.bodyMedium,
                ),
                onTap: () => context.push('/settings/paragraphreader'),
              ),
              ListTile(
                title: Text(
                  'Image List Reader',
                  style: context.bodyMedium,
                ),
                onTap: () => context.push('/settings/imagelistreader'),
              ),
              ListTile(
                title: Text(
                  'Sync Settings',
                  style: context.bodyMedium,
                ),
                onTap: () => context.push('/settings/sync'),
              ),
              ListTile(
                title: Text(
                  'Storage',
                  style: context.bodyMedium,
                ),
                onTap: () => context.push('/settings/storage'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
