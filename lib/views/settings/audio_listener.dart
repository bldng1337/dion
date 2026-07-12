import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_bindings.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';

class AudioListenerSettings extends StatelessWidget {
  const AudioListenerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          SettingTitle(
            title: 'Playback',
            subtitle: 'Audio playback settings',
            children: [
              SettingSlider(
                title: 'Volume',
                description: 'Master volume level',
                min: 1.0,
                max: 100.0,
                step: 5.0,
                setting: settings.audioBookSettings.volume,
              ),
              SettingSlider(
                title: 'Playback Speed',
                description: 'Audio playback speed multiplier',
                min: 0.5,
                max: 4.0,
                step: 0.25,
                setting: settings.audioBookSettings.speed,
              ),
            ],
          ),

          SettingTitle(
            title: 'Controls',
            subtitle: 'Keybinds & gestures',
            children: [
              SettingBindings(
                title: 'Play / Pause',
                description: 'Inputs that toggle playback',
                icon: Icons.play_arrow,
                setting: settings.audioBookSettings.bindings.playPause,
              ),
              SettingBindings(
                title: 'Seek Forward',
                description: 'Inputs that seek 5 seconds forward',
                icon: Icons.forward_5,
                setting: settings.audioBookSettings.bindings.seekForward,
              ),
              SettingBindings(
                title: 'Seek Backward',
                description: 'Inputs that seek 5 seconds backward',
                icon: Icons.replay_5,
                setting: settings.audioBookSettings.bindings.seekBackward,
              ),
              SettingBindings(
                title: 'Next Chapter',
                description: 'Inputs that advance to the next chapter',
                icon: Icons.skip_next,
                setting: settings.audioBookSettings.bindings.nextChapter,
              ),
              SettingBindings(
                title: 'Previous Chapter',
                description: 'Inputs that go back to the previous chapter',
                icon: Icons.skip_previous,
                setting: settings.audioBookSettings.bindings.prevChapter,
              ),
              SettingBindings(
                title: 'Toggle Bookmark',
                description: 'Inputs that toggle the chapter bookmark',
                icon: Icons.bookmark_border,
                setting: settings.audioBookSettings.bindings.toggleBookmark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
