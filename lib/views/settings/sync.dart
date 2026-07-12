import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_directory.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class SyncSettings extends StatelessWidget {
  const SyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Synchronisation',
            subtitle: 'Configure cloud sync and backup',
            children: [
              SettingToggle(
                title: 'Enable Sync',
                description: 'Automatically sync your library',
                setting: settings.sync.enabled,
              ),
              SettingDirectory(
                title: 'Sync Directory',
                description: 'Folder to sync library data',
                setting: settings.sync.path,
              ).conditional(settings.sync.enabled),
            ],
          ),
          SettingTitle(
            title: 'Local Network Sync',
            subtitle: 'Pair with other devices on your Wi-Fi to sync directly',
            children: [
              SettingToggle(
                title: 'Enable LAN Sync',
                description: 'Discover and pair with nearby devices',
                setting: settings.sync.lan.enabled,
              ),
              SettingTextbox(
                title: 'Device Name',
                description: 'Shown to other devices when pairing',
                setting: settings.sync.lan.deviceName,
              ).conditional(settings.sync.lan.enabled),
              SettingToggle(
                title: 'Discoverable',
                description: 'Let other devices find this device',
                setting: settings.sync.lan.discoverable,
              ).conditional(settings.sync.lan.enabled),
            ],
          ),
        ],
      ),
    );
  }
}
