import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class UpdateSettings extends StatelessWidget {
  const UpdateSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Notifications',
            subtitle: 'When to notify about updates',
            children: [
              SettingToggle(
                title: 'Patch Updates',
                description: 'Notify when patch versions are available',
                setting: settings.update.patch,
              ),
              SettingToggle(
                title: 'Minor Updates',
                description: 'Notify when minor versions are available',
                setting: settings.update.minor,
              ),
            ],
          ),

          SettingTitle(
            title: 'Channel',
            subtitle: 'Select update channel',
            children: [
              SettingDropdown(
                title: 'Update Channel',
                description: 'Choose between stable and beta releases',
                setting: settings.update.channel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
