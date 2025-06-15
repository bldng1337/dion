import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:flutter/material.dart';

class AudioListenerSettings extends StatelessWidget {
  const AudioListenerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [
          SettingSlider(
            title: 'Volume',
            description: 'The volume of the audio',
            min: 1.0,
            max: 100.0,
            setting: settings.audioBookSettings.volume,
          ),
          SettingSlider(
            title: 'Speed',
            description: 'The speed of the audio',
            min: 0.5,
            max: 4.0,
            setting: settings.audioBookSettings.speed,
          ),
        ],
      ),
    );
  }
}
