import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_stringlist.dart';
import 'package:flutter/widgets.dart';

class ExtensionSettings extends StatelessWidget {
  const ExtensionSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [SettingStringList(setting: settings.extension.repositories)],
      ),
    );
  }
}
