import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/util/settingsapi.dart';
import 'package:dionysos/util/update.dart';
import 'package:dionysos/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:language_code/language_code.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/link.dart';

const SettingsCategory library = SettingsCategory('library');

class LibrarySettings {
  static const SettingBoolean sortdesc =
      SettingBoolean('sortdesc', false, category: library);
  static const SettingString sortcategory =
      SettingString('sortkey', 'epsuncompleted', category: library);

  static const SettingBoolean shouldfiltermediatype =
      SettingBoolean('filtermediatypetoggle', false, category: library);
  static const SettingString filtermediatype =
      SettingString('filtermediatype', 'book', category: library);

  static const SettingBoolean shouldfilterstatus =
      SettingBoolean('filtermediatypetoggle', false, category: library);
  static const SettingString filterstatus =
      SettingString('filtermediatype', 'complete', category: library);
}

const SettingsCategory sync = SettingsCategory('sync');

class SyncSetting {
  static const SettingDirectory dir = SettingDirectory('path', category: sync);
}

const SettingsCategory videoplayer = SettingsCategory('rvidplayer');

class VideoplayerSetting {
  static const SettingBoolean autousesubtitle =
      SettingBoolean('autosub', true, category: videoplayer);
  static const SettingLanguage defaultsubtitle =
      SettingLanguage('defsub', LanguageCodes.en, category: videoplayer);
  static const SettingBoolean autoplaynext =
      SettingBoolean('autonext', false, category: videoplayer);
}

const SettingsCategory mangareader = SettingsCategory('rimglist');

class MangareaderSetting {
  static const SettingDouble imagewidth =
      SettingDouble('imagewidth', 25, category: mangareader);
  static const SettingBoolean adaptivewidth =
      SettingBoolean('adaptivetwidth', true, category: mangareader);
}

const SettingsCategory textreader = SettingsCategory('rparagraph');

class TextReaderSettings {
  static const SettingString reader =
      SettingString('reader', 'Paginated', category: textreader);
  static const SettingString textweight =
      SettingString('textweight', 'w400', category: textreader);
  static const SettingDouble textsize =
      SettingDouble('textsize', 25, category: textreader);
  static const SettingDouble textwidth =
      SettingDouble('textwidth', 25, category: textreader);
  static const SettingBoolean adaptivewidth =
      SettingBoolean('adaptivetwidth', true, category: textreader);
  static const SettingBoolean bionic =
      SettingBoolean('bionictoggle', false, category: textreader);
  static const SettingDouble bionicpercent =
      SettingDouble('bionicpercent', 0.1, category: textreader);
  static const SettingString bionichighlight =
      SettingString('bionichighlight', 'w500', category: textreader);
}

final settingspage = SettingPageBuilder('Settings', [
  SettingsNavTile(
    'Text Reader',
    'Settings for the PlainText Reader',
    textreadersettings,
    icon: Icons.menu_book_outlined,
  ),
  const SettingsNavTile(
    'Mangareader',
    'Settings for Mangareader',
    mangareadersettings,
    icon: Icons.broken_image,
  ),
  const SettingsNavTile(
    'Videoplayer',
    'Settings for the Videoplayer',
    videoplayersettings,
    icon: Icons.video_camera_back_rounded,
  ),
  SettingsNavTile(
    'Sync',
    'Settings for Syncronisation',
    syncsettings,
    icon: Icons.broken_image,
  ),
  SettingsNavTile(
    'Library',
    'Settings for Library',
    librarysettings,
    icon: Icons.library_books_sharp,
  ),
  SettingsNavTile(
    'About',
    'About the Application',
    aboutpage,
    icon: Icons.info,
  ),
]);

final aboutpage = SettingPageBuilder('About', [
  WidgetTile(
    (c) => Column(
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(15),
              child: Image(
                image: AssetImage('assets/icon/icon.png'),
                height: 130,
              ),
            ),
            FutureLoader(
              getVersion(),
              success: (context, data) => Text(
                'dion v$data',
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ],
        ),
        
        Link(
          uri: Uri.parse('https://github.com/bldng1337/dion'),
          builder: (context, followLink) =>
              TextButton(onPressed: followLink, child: const Icon(SimpleIcons.github)),
        ),
        TextButton(onPressed: () async {
          final Update? update = await checkUpdate();
          if (update != null && c.mounted) {
            showUpdateDialog(c, update);
          }
        }, child: const Icon(SimpleIcons.upcloud),),
      ],
    ),
  ),
]);

const todo = SettingPageBuilder('TODO', []);
final librarysettings = SettingPageBuilder('Manga Reader Settings', [
  const SortingTile(
      'Sorting',
      'How the Entries in the Library should be sorted',
      LibrarySettings.sortcategory,
      LibrarySettings.sortdesc, [
    Choice('Episodes not Completed', 'epsuncompleted'),
    Choice('Episodes Completed', 'epscompleted'),
    Choice('Total Episodes', 'epstotal'),
  ]),
  const BooleanTile(
    'Filter Media Type',
    'Filter by media type',
    LibrarySettings.shouldfiltermediatype,
    icon: Icons.filter_alt_sharp,
  ),
  ConditionalTile(
    LibrarySettings.shouldfiltermediatype,
    SimpleChoiceTile(
      'Media Type Filter',
      'By which media type to filter',
      LibrarySettings.filtermediatype,
      choices: MediaType.values
          .map((e) => e.toString().replaceFirst('MediaType.', ''))
          .toList(),
    ),
  ),
  const BooleanTile(
    'Filter Status',
    'Filter by status',
    LibrarySettings.shouldfilterstatus,
    icon: Icons.filter_alt_sharp,
  ),
  ConditionalTile(
    LibrarySettings.shouldfilterstatus,
    SimpleChoiceTile(
      'Filter Status',
      'By which status to filter',
      LibrarySettings.filtermediatype,
      choices: Status.values
          .map((e) => e.toString().replaceFirst('Status.', ''))
          .toList(),
    ),
  ),
  const CategoryTile('Category', 'Categories to sort Entries in the Library'),
]);

final SettingPageBuilder syncsettings = SettingPageBuilder('Sync Settings', [
  const DirectoryTile(
    'SyncPath',
    'Path where the sync file should be stored',
    SyncSetting.dir,
  ),
  WidgetTile((c) => const ConstructionWarning()),
]);

const SettingPageBuilder videoplayersettings =
    SettingPageBuilder('Videoplayer Settings', [
  BooleanTile(
    'Auto Subtitle',
    'Auto Select a Subtitle if its available',
    VideoplayerSetting.autousesubtitle,
  ),
  ConditionalTile(
    VideoplayerSetting.autousesubtitle,
    LanguageTile(
      'Subtitle',
      'Subtitle that gets auto selected if available',
      VideoplayerSetting.defaultsubtitle,
      icon: Icons.subtitles_rounded,
    ),
  ),
]);

const SettingPageBuilder mangareadersettings =
    SettingPageBuilder('Manga Reader Settings', [
  DoubleTile(
    'Image width',
    'Width of Images',
    MangareaderSetting.imagewidth,
    icon: Icons.width_full,
    min: 20,
    max: 100,
  ),
  BooleanTile(
    'Adaptive Width',
    'Turns Text width off on vertical orientation',
    MangareaderSetting.adaptivewidth,
    icon: Icons.width_wide,
  ),
]);



final SettingPageBuilder textreadersettings =
    SettingPageBuilder('Textreader Settings', [
  const SimpleChoiceTile(
    'ReaderChoice',
    'Which Reader you want to use',
    TextReaderSettings.reader,
    choices: ['Paginated', 'Infinityscroll'],
    icon: Icons.book,
  ),
  SimpleChoiceTile(
    'TextWeight',
    'Textweight of characters',
    TextReaderSettings.textweight,
    choices: FontWeight.values
        .map((e) => fontWeightToString(e))
        .toSet()
        .toList(),
    icon: Icons.highlight,
  ),
  const DoubleTile(
    'Textsize',
    'Size of the Text',
    TextReaderSettings.textsize,
    icon: Icons.format_size_outlined,
    min: 1,
    max: 50,
  ),
  const DoubleTile(
    'TextWidth',
    'Width of a Text line in Percent',
    TextReaderSettings.textwidth,
    icon: Icons.width_full,
    min: 20,
    max: 100,
  ),
  const BooleanTile(
    'Adaptive Width',
    'Turns Text width off on vertical orientation',
    TextReaderSettings.adaptivewidth,
    icon: Icons.width_wide,
  ),
  const BooleanTile(
    'Bionic',
    'Toggle Bionic Reading(highlights first character in word)',
    TextReaderSettings.bionic,
    icon: Icons.remove_red_eye,
  ),
  const ConditionalTile(
    TextReaderSettings.bionic,
    DoubleTile(
      'Word Percentage',
      'Percentage of the Word that will get highlighted',
      TextReaderSettings.bionicpercent,
      icon: Icons.keyboard_double_arrow_right,
      min: 0.1,
    ),
  ),
  ConditionalTile(
    TextReaderSettings.bionic,
    SimpleChoiceTile(
      'BionicWeight',
      'Textweight of characters highlighted',
      TextReaderSettings.bionichighlight,
      choices: FontWeight.values
          .map((e) => fontWeightToString(e))
          .toSet()
          .toList(),
    ),
  ),
]);
