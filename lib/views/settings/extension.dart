import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_stringlist.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/widgets.dart';

class ExtensionSettings extends StatelessWidget {
  const ExtensionSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Repositories',
            subtitle: 'Extension sources for installation',
            children: [
              SettingStringList(
                setting: settings.extension.repositories,
                title: 'Repository URLs',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
