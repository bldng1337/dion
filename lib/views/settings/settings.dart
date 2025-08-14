import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/routes.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/widgets.dart';
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
              DionListTile(
                title: Text('Paragraph Reader', style: context.bodyMedium),
                onTap: () => context.push('/settings/paragraphreader'),
              ),
              DionListTile(
                title: Text('Audio Listener', style: context.bodyMedium),
                onTap: () => context.push('/settings/audiolistener'),
              ),
              DionListTile(
                title: Text('Image List Reader', style: context.bodyMedium),
                onTap: () => context.push('/settings/imagelistreader'),
              ),
              DionListTile(
                title: Text('Synchronisation', style: context.bodyMedium),
                onTap: () => context.push('/settings/sync'),
              ),
              DionListTile(
                title: Text('Storage', style: context.bodyMedium),
                onTap: () => context.push('/settings/storage'),
              ),
              DionListTile(
                title: Text('Library', style: context.bodyMedium),
                onTap: () => context.push('/settings/library'),
              ),
              DionListTile(
                title: Text('Update', style: context.bodyMedium),
                onTap: () => context.push('/settings/update'),
              ),
              DionListTile(
                title: Text('Active Tasks', style: context.bodyMedium),
                onTap: () => context.push('/settings/tasks'),
              ),
              DionListTile(
                title: Text('Developer Settings', style: context.bodyMedium),
                onTap: () => context.push('/dev'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
