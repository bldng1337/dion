import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_directory.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class SyncSettings extends StatelessWidget {
  const SyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Synchronisation'),
      child: ListenableBuilder(
        listenable: settings.sync.mode,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
          children: [
            SettingTitle(
              title: 'Synchronisation',
              subtitle: 'How this device keeps its library in sync',
              children: [
                SettingDropdown(
                  title: 'Sync Mode',
                  description:
                      'Merge with a database file in a folder, or sync '
                      'directly with paired devices on your network',
                  setting: settings.sync.mode,
                ),
              ],
            ),
            if (settings.sync.mode.value == SyncMode.file)
              SettingTitle(
                title: 'Local Database File',
                subtitle: 'Merged into your library each time the app starts',
                children: [
                  SettingDirectory(
                    title: 'Sync Directory',
                    description: 'Folder holding the database to merge with',
                    setting: settings.sync.path,
                  ),
                ],
              ),
            if (settings.sync.mode.value == SyncMode.lan)
              SettingTitle(
                title: 'LAN Sync',
                subtitle:
                    'Pair with other devices on your Wi-Fi to sync directly',
                children: [
                  SettingTextbox(
                    title: 'Device Name',
                    description: 'Shown to other devices when pairing',
                    setting: settings.sync.lan.deviceName,
                  ),
                  SettingToggle(
                    title: 'Discoverable',
                    description: 'Let other devices find this device',
                    setting: settings.sync.lan.discoverable,
                  ),
                  SettingToggle(
                    title: 'Auto Sync',
                    description:
                        'Sync with paired devices automatically whenever both '
                        'are online',
                    setting: settings.sync.lan.autoSync,
                  ),
                  SettingToggle(
                    title: 'Live Sync',
                    description:
                        'Push changes to online devices as they happen instead '
                        'of waiting for the next sync',
                    setting: settings.sync.lan.livesync,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
