import 'dart:async';

import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final SourceSupplier source;
  const SimpleVideoPlayer({super.key, required this.source});

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer>
    with StateDisposeScopeMixin {
  late final Player player;
  late final VideoController controller;
  Subtitles? subtitle;
  List<Subtitles> get subtitles {
    if (widget.source.source == null) return [];
    final source = widget.source.source!;
    if (source.source.sourcedata is! LinkSource_M3u8) {
      return [];
    }
    final sourcedata = source.source.sourcedata as LinkSource_M3u8;
    return sourcedata.sub;
  }

  Future<void> initPlayer() async {
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    controller = VideoController(player);
    Observer(
      () async {
        if (widget.source.source == null) {
          player.stop();
          return;
        }
        final source = widget.source.source!;
        if (source.source.sourcedata is! LinkSource_M3u8) {
          return;
        }
        final sourcedata = source.source.sourcedata as LinkSource_M3u8;
        Duration startduration = Duration.zero;
        if (source.episode.data.progress != null) {
          startduration = Duration(
            milliseconds: int.tryParse(source.episode.data.progress!) ?? 0,
          );
        }
        await player.open(
          Media(sourcedata.link, start: startduration),
        );
        print('Opening ${sourcedata.link}');
        await player.setSubtitleTrack(SubtitleTrack.no());
      },
      [widget.source],
    );
    locate<PlayerService>().setSession(
      PlaySession(
        widget.source,
        player,
        gonext: () {
          if (mounted) {
            widget.source.episode.goNext(widget.source);
          }
        },
        goprev: () {
          if (mounted) {
            widget.source.episode.goPrev(widget.source);
          }
        },
      )..disposedBy(scope),
    );
    Observer(
      () {
        player.setVolume(settings.audioBookSettings.volume.value);
      },
      [settings.audioBookSettings.volume],
    ).disposedBy(scope);
    Observer(
      () {
        player.setRate(settings.audioBookSettings.speed.value);
      },
      [settings.audioBookSettings.speed],
    ).disposedBy(scope);
    await player.setPlaylistMode(PlaylistMode.none);

    player.stream.completed.listen((event) {
      if (!event) {
        return;
      }
      if (!mounted) {
        return;
      }
      widget.source.episode.goNext(widget.source);
    });
    player.stream.position.listen((event) {
      if (!mounted) {
        return;
      }
      final playlistindex = player.state.playlist.index;
      widget.source.episode.data.progress =
          '$playlistindex:${event.inMilliseconds}';
      if (event.inMilliseconds / player.state.duration.inMilliseconds > 0.5 &&
          playlistindex / player.state.playlist.medias.length > 0.5) {
        widget.source.preload(widget.source.episode.next);
      }
    });
  }

  @override
  void initState() {
    initPlayer();
    super.initState();
  }

  @override
  void dispose() {
    widget.source.episode.save();
    player.dispose();
    super.dispose();
  }

  String getTitle() {
    if (player.state.playlist.medias.isEmpty ||
        player.state.playlist.medias.length <= player.state.playlist.index) {
      return widget.source.episode.name;
    }
    final title = player.state.playlist.medias[player.state.playlist.index]
        .extras?['title'] as String?;
    if (title == null || title == 'default') {
      return widget.source.episode.name;
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    return NavScaff(
      actions: [
        DionIconbutton(
          icon: Icon(epdata.bookmark ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () async {
            epdata.bookmark = !epdata.bookmark;
            await widget.source.episode.save();
            if (mounted) {
              setState(() {});
            }
          },
        ),
        DionIconbutton(
          icon: const Icon(Icons.open_in_browser),
          onPressed: () =>
              launchUrl(Uri.parse(widget.source.episode.episode.url)),
        ),
        DionIconbutton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings/audiolistener'),
        ),
      ],
      title: StreamBuilder(
        stream: player.stream.playlist,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Text(widget.source.episode.name);
          return Text(getTitle());
        },
      ),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          child: MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              bottomButtonBarMargin: const EdgeInsets.all(15),
              seekBarMargin: const EdgeInsets.all(15),
              // Modify top button bar:
              topButtonBar: [
                IconButton(
                  onPressed: () {
                    context.pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
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
                  items: subtitles
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    subtitle = value;
                    if (value == null) {
                      player.setSubtitleTrack(SubtitleTrack.no());
                      return;
                    }
                    player.setSubtitleTrack(
                      SubtitleTrack.uri(
                        value.url,
                        title: value.title,
                      ),
                    );
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
