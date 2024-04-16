import 'package:dionysos/Source.dart';
import 'package:dionysos/page/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:language_code/language_code.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class Videoplayer extends StatefulWidget {
  final M3U8Source _source;
  const Videoplayer(this._source, {super.key});

  @override
  createState() => _VideoplayerState();
}

class _VideoplayerState extends State<Videoplayer> {
  late M3U8Source source;
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    source=widget._source;
    super.initState();
    player = Player(
      configuration: PlayerConfiguration(
        title: source.ep.name,
      ),
    );
    controller = VideoController(player);
    player.open(Media(source.url));
    if (VideoplayerSetting.autousesubtitle.value) {
      LanguageCodes lang = VideoplayerSetting.defaultsubtitle.value;
      if (source.sub.containsKey(lang)) {
        setSubtitle(lang);
      }
    }
    
  }

  void setSubtitle(LanguageCodes lang) {
    player.setSubtitleTrack(
      SubtitleTrack.uri(source.sub[lang] ?? "",
          title: lang.nativeName, language: lang.locale.countryCode
          // language: 'en',
          ),
    );
    subtitle = lang;
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  LanguageCodes? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          child: MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              bottomButtonBarMargin: const EdgeInsets.all(15),
              seekBarMargin: const EdgeInsets.all(15),
              // Modify theme options:
              buttonBarButtonSize: 24.0,
              buttonBarButtonColor: Colors.white,
              // Modify top button bar:
              topButtonBar: [
                IconButton(
                    onPressed: () {
                      context.pop();
                    },
                    icon: const Icon(Icons.arrow_back)),
                const Spacer(),
                MaterialDesktopCustomButton(
                  onPressed: () {
                    debugPrint('Custom "Settings" button pressed.');
                  },
                  icon: const Icon(Icons.settings),
                ),
                DropdownButton(
                  value: subtitle,
                  icon: const Icon(Icons.subtitles),
                  items: source.sub.keys
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.nativeName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if(value!=null){
                      setSubtitle(value);
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            fullscreen: const MaterialVideoControlsThemeData(
              // Modify theme options:

              displaySeekBar: false,
              automaticallyImplySkipNextButton: false,
              automaticallyImplySkipPreviousButton: false,
            ),
            child: Video(
              controller: controller,
              controls: MaterialVideoControls,
            ),
          ),
        ),
      ),
    );
  }
}
