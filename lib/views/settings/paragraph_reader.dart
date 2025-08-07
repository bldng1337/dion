import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
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
        children: [
          SettingDropdown(
            title: 'ReaderMode',
            setting: settings.readerSettings.paragraphreader.mode,
          ),
          SettingToggle(
            title: 'Title',
            description:
                'Should the title be displayed at the head of the Chapter',
            setting: settings.readerSettings.paragraphreader.title,
          ),
          SettingTitle(
            title: 'Text Settings',
            children: [
              SettingToggle(
                title: 'Adaptive Width',
                description: 'Auto sets the line width to 0 in portrait mode',
                setting:
                    settings.readerSettings.paragraphreader.text.adaptivewidth,
              ),
              SettingSlider(
                title: 'Line Width',
                description: 'The width of a line in the text',
                min: 10.0,
                max: 100.0,
                setting: settings.readerSettings.paragraphreader.text.linewidth,
              ),
              SettingSlider(
                title: 'Text Size',
                description: 'The size of the text',
                min: 10,
                max: 30,
                setting: settings.readerSettings.paragraphreader.text.size,
              ),
              SettingSlider(
                title: 'Text Weight',
                description: 'The thickness of the text',
                min: 0.1,
                max: 1.0,
                setting: settings.readerSettings.paragraphreader.text.weight,
              ),
              SettingSlider(
                title: 'Line Spacing',
                description: 'The space between lines',
                min: 1.0,
                max: 10.0,
                setting:
                    settings.readerSettings.paragraphreader.text.linespacing,
              ),
              SettingSlider(
                title: 'Paragraph Spacing',
                description: 'The space between paragraphs',
                min: 1.0,
                max: 10.0,
                setting: settings
                    .readerSettings
                    .paragraphreader
                    .text
                    .paragraphspacing,
              ),
              SettingToggle(
                title: 'Selectable',
                description: 'Should the text be selectable',
                setting:
                    settings.readerSettings.paragraphreader.text.selectable,
              ),
              // TODO: Implement bionic reading
              // SettingToggle(
              //   title: 'Bionic Reading',
              //   description: 'Should the first part of each word be highlighted',
              //   setting:
              //       settings.readerSettings.paragraphreader.text.bionicreading,
              // ),
              // SettingSlider(
              //   title: 'Bionic Weight',
              //   description: 'The thickness of the highlighted text',
              //   min: 0.1,
              //   max: 1.0,
              //   setting:
              //       settings.readerSettings.paragraphreader.text.bionicweight,
              // ),
            ],
          ),
        ],
      ),
    );
  }
}
