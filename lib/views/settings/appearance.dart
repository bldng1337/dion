import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/widgets.dart';

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Theme'),
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Theme',
            subtitle: 'How the app looks',
            children: [
              SettingDropdown(
                title: 'Appearance',
                description: 'Use a light or dark color scheme',
                setting: settings.appearance.theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
