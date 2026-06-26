import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/widgets.dart';

class VideoPlayerSettings extends StatelessWidget {
  const VideoPlayerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Playback',
            subtitle: 'Video playback settings',
            children: [
              SettingSlider(
                title: 'Volume',
                description: 'Master volume level',
                min: 1.0,
                max: 100.0,
                step: 5.0,
                setting: settings.videoSettings.volume,
              ),
              SettingSlider(
                title: 'Playback Speed',
                description: 'Video playback speed multiplier',
                min: 0.5,
                max: 4.0,
                step: 0.25,
                setting: settings.videoSettings.speed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
