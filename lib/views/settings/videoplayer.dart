import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_bindings.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';

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

          SettingTitle(
            title: 'Controls',
            subtitle: 'Keybinds & gestures',
            children: [
              SettingBindings(
                title: 'Next Chapter',
                description: 'Inputs that advance to the next chapter',
                icon: Icons.skip_next,
                setting: settings.videoSettings.bindings.nextChapter,
              ),
              SettingBindings(
                title: 'Previous Chapter',
                description: 'Inputs that go back to the previous chapter',
                icon: Icons.skip_previous,
                setting: settings.videoSettings.bindings.prevChapter,
              ),
              SettingBindings(
                title: 'Toggle Bookmark',
                description: 'Inputs that toggle the chapter bookmark',
                icon: Icons.bookmark_border,
                setting: settings.videoSettings.bindings.toggleBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
