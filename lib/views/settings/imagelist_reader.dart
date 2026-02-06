import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class ImageListReaderSettings extends StatelessWidget {
  const ImageListReaderSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Display',
            subtitle: 'Image display settings',
            children: [
              SettingDropdown(
                title: 'Reader Mode',
                description: 'How images are displayed',
                setting: settings.readerSettings.imagelistreader.mode,
              ),
              SettingToggle(
                title: 'Adaptive Width',
                description: 'Auto-adjust width in portrait mode',
                setting: settings.readerSettings.imagelistreader.adaptivewidth,
              ),
              SettingSlider(
                title: 'Image Width',
                description: 'Maximum width of images (%)',
                min: 10.0,
                max: 100.0,
                step: 5.0,
                setting: settings.readerSettings.imagelistreader.width,
              ),
            ],
          ),

          SettingTitle(
            title: 'Audio',
            subtitle: 'Background music settings',
            children: [
              SettingToggle(
                title: 'Background Music',
                description: 'Play music while reading',
                setting: settings.readerSettings.imagelistreader.music,
              ),
              SettingSlider(
                title: 'Music Volume',
                description: 'Volume level for background music',
                min: 0.0,
                max: 100.0,
                step: 5.0,
                setting: settings.readerSettings.imagelistreader.volume,
              ).conditional(settings.readerSettings.imagelistreader.music),
            ],
          ),
        ],
      ),
    );
  }
}
