import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';

class UpdateSettings extends StatelessWidget {
  const UpdateSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [
          SettingToggle(
            title: 'Notify on Patch',
            setting: settings.update.patch,
          ),
          SettingToggle(
            title: 'Notify on Minor',
            setting: settings.update.minor,
          ),
          SettingDropdown(
            setting: settings.update.channel,
            title: 'Update Channel',
          ),
        ],
      ),
    );
  }
}
