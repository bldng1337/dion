import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
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
        children: [
          SettingDropdown(
            title: 'ReaderMode',
            setting: settings.readerSettings.imagelistreader.mode,
          ),
          SettingToggle(
            title: 'Adaptive Width',
            description: 'Auto sets the width to full in portrait mode',
            setting: settings.readerSettings.imagelistreader.adaptivewidth,
          ),
          SettingSlider(
            title: 'Line Width',
            description: 'The width of the image',
            min: 10.0,
            max: 100.0,
            setting: settings.readerSettings.imagelistreader.width,
          ),
          SettingTitle(
            title: 'Music Settings',
            children: [
              SettingToggle(
                title: 'Music',
                description: 'Should the music be played',
                setting: settings.readerSettings.imagelistreader.music,
              ),
              SettingSlider(
                title: 'Music Volume',
                description: 'The volume of the music',
                min: 0.0,
                max: 100.0,
                setting: settings.readerSettings.imagelistreader.volume,
              ).conditional(settings.readerSettings.imagelistreader.music),
            ],
          ),
        ],
      ),
    );
  }
}
