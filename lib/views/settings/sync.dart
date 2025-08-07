import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_directory.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class SyncSettings extends StatelessWidget {
  const SyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [
          SettingToggle(title: 'Enable Sync', setting: settings.sync.enabled),
          SettingDirectory(
            title: 'Sync Path',
            setting: settings.sync.path,
          ).conditional(settings.readerSettings.imagelistreader.music),
        ],
      ),
    );
  }
}
