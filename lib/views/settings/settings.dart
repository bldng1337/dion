import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/routes.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart' show BorderRadius, Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class SettingNav extends StatelessWidget {
  final String title;
  final IconData icon;
  final String path;
  const SettingNav({
    super.key,
    required this.title,
    required this.icon,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return DionListTile(
      leading: Icon(icon),
      title: Text(title, style: context.bodyMedium),
      onTap: () => context.push(path),
    );
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Settings'),
      destination: homedestinations,
      child: ListView(
        children: const [
          SettingTitle(
            title: 'Reader Settings',
            children: [
              SettingNav(
                title: 'Paragraph Reader',
                icon: Icons.article,
                path: '/settings/paragraphreader',
              ),
              SettingNav(
                title: 'Audio Listener',
                icon: Icons.audiotrack,
                path: '/settings/audiolistener',
              ),
              SettingNav(
                title: 'Image List Reader',
                icon: Icons.image,
                path: '/settings/imagelistreader',
              ),
            ],
          ),
          SettingTitle(
            title: 'Sync & Storage',
            children: [
              SettingNav(
                title: 'Synchronisation',
                icon: Icons.sync,
                path: '/settings/sync',
              ),
              SettingNav(
                title: 'Storage',
                icon: Icons.sd_storage,
                path: '/settings/storage',
              ),
            ],
          ),
          SettingTitle(
            title: 'Library & Maintenance',
            children: [
              SettingNav(
                title: 'Library',
                icon: Icons.local_library,
                path: '/settings/library',
              ),
              SettingNav(
                title: 'Update',
                icon: Icons.system_update,
                path: '/settings/update',
              ),
              SettingNav(
                title: 'Active Tasks',
                icon: Icons.playlist_play,
                path: '/settings/tasks',
              ),
            ],
          ),
          SettingTitle(
            title: 'Developer & Extensions',
            children: [
              SettingNav(
                title: 'Developer Settings',
                icon: Icons.developer_mode,
                path: '/dev',
              ),
              SettingNav(
                title: 'Extension Settings',
                icon: Icons.extension,
                path: '/settings/extension',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
