import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_bindings.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';

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

          SettingTitle(
            title: 'Controls',
            subtitle: 'Keybinds & gestures',
            children: [
              SettingBindings(
                title: 'Next Chapter',
                description: 'Inputs that advance to the next chapter',
                icon: Icons.skip_next,
                setting:
                    settings.readerSettings.imagelistreader.bindings.nextChapter,
              ),
              SettingBindings(
                title: 'Previous Chapter',
                description: 'Inputs that go back to the previous chapter',
                icon: Icons.skip_previous,
                setting:
                    settings.readerSettings.imagelistreader.bindings.prevChapter,
              ),
              SettingBindings(
                title: 'Toggle Bookmark',
                description: 'Inputs that toggle the chapter bookmark',
                icon: Icons.bookmark_border,
                setting: settings
                    .readerSettings
                    .imagelistreader
                    .bindings
                    .toggleBookmark,
              ),
              SettingBindings(
                title: 'Jump Down',
                description: 'Inputs that scroll down',
                icon: Icons.arrow_downward,
                setting:
                    settings.readerSettings.imagelistreader.bindings.jumpDown,
              ),
              SettingBindings(
                title: 'Jump Up',
                description: 'Inputs that scroll up',
                icon: Icons.arrow_upward,
                setting: settings.readerSettings.imagelistreader.bindings.jumpUp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
