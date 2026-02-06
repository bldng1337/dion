import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_font.dart';
import 'package:dionysos/widgets/settings/setting_slider.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/widgets.dart';

class ParagraphReaderSettings extends StatelessWidget {
  const ParagraphReaderSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          // Top-level settings without a section
          SettingItem(
            child: SettingDropdown(
              title: 'Reader Mode',
              description: 'How the reader displays content',
              setting: settings.readerSettings.paragraphreader.mode,
            ),
          ),

          const SizedBox(height: DionSpacing.sm),

          SettingItem(
            child: SettingToggle(
              title: 'Show Title',
              description: 'Display the chapter title at the top',
              setting: settings.readerSettings.paragraphreader.title,
            ),
          ),

          // Title Settings Section
          SettingTitle(
            title: 'Title Appearance',
            subtitle: 'Customize how chapter titles are displayed',
            children: [
              SettingSlider(
                title: 'Title Size',
                description: 'Size of the chapter title text',
                min: 10,
                max: 60,
                setting:
                    settings.readerSettings.paragraphreader.titleSettings.size,
              ),
              SettingToggle(
                title: 'Thumbnail Banner',
                description: 'Show thumbnail image behind the title',
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .titleSettings
                    .thumbBanner,
              ),
            ],
          ).conditional(settings.readerSettings.paragraphreader.title),

          // Text Settings Section
          SettingTitle(
            title: 'Typography',
            subtitle: 'Font and text formatting options',
            children: [
              SettingFont(
                title: 'Font',
                description: 'The font used for reading',
                setting: settings.readerSettings.paragraphreader.font,
              ),
              SettingSlider(
                title: 'Text Size',
                description: 'Size of the body text',
                min: 10,
                max: 30,
                setting: settings.readerSettings.paragraphreader.text.size,
              ),
              SettingSlider(
                title: 'Text Weight',
                description: 'Thickness of the text',
                min: 0.1,
                max: 1.0,
                step: 0.1,
                setting: settings.readerSettings.paragraphreader.text.weight,
              ),
            ],
          ),

          // Layout Settings Section
          SettingTitle(
            title: 'Layout',
            subtitle: 'Spacing and width settings',
            children: [
              SettingToggle(
                title: 'Adaptive Width',
                description: 'Auto-adjust line width in portrait mode',
                setting:
                    settings.readerSettings.paragraphreader.text.adaptivewidth,
              ),
              SettingSlider(
                title: 'Line Width',
                description: 'Maximum width of text lines (%)',
                min: 10.0,
                max: 100.0,
                step: 5.0,
                setting: settings.readerSettings.paragraphreader.text.linewidth,
              ),
              SettingSlider(
                title: 'Line Spacing',
                description: 'Space between lines of text',
                min: 1.0,
                max: 10.0,
                step: 0.5,
                setting:
                    settings.readerSettings.paragraphreader.text.linespacing,
              ),
              SettingSlider(
                title: 'Paragraph Spacing',
                description: 'Space between paragraphs',
                min: 1.0,
                max: 10.0,
                step: 0.5,
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .text
                    .paragraphspacing,
              ),
            ],
          ),

          // Interaction Settings Section
          SettingTitle(
            title: 'Interaction',
            subtitle: 'Reading interaction options',
            children: [
              SettingToggle(
                title: 'Selectable Text',
                description: 'Allow selecting and copying text',
                setting:
                    settings.readerSettings.paragraphreader.text.selectable,
              ),
            ],
          ),

          // Bionic Reading Section
          SettingTitle(
            title: 'Bionic Reading',
            subtitle: 'Speed reading assistance',
            children: [
              SettingToggle(
                title: 'Enable Bionic Reading',
                description: 'Highlight the first part of each word',
                setting: settings.readerSettings.paragraphreader.text.bionic,
              ),
            ],
          ),

          // Bionic Settings (conditional)
          SettingTitle(
            title: 'Bionic Settings',
            subtitle: 'Customize the bionic reading effect',
            children: [
              SettingSlider(
                title: 'Highlight Weight',
                description: 'Thickness of highlighted letters',
                min: 0.1,
                max: 1.0,
                step: 0.1,
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .text
                    .bionicSettings
                    .bionicWheight,
              ),
              SettingSlider(
                title: 'Highlight Size',
                description: 'Size of highlighted letters',
                min: 10,
                max: 40,
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .text
                    .bionicSettings
                    .bionicSize,
              ),
              SettingSlider(
                title: 'Letters to Highlight',
                description: 'Number of letters per word to highlight',
                min: 1,
                max: 5,
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .text
                    .bionicSettings
                    .letters,
              ),
            ],
          ).conditional(settings.readerSettings.paragraphreader.text.bionic),
        ],
      ),
    );
  }
}
