import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:url_launcher/url_launcher.dart';

class SimpleAudioListener extends StatefulWidget {
  final SourceSupplier source;
  const SimpleAudioListener({super.key, required this.source});

  @override
  State<SimpleAudioListener> createState() => _SimpleAudioListenerState();
}

class _SimpleAudioListenerState extends State<SimpleAudioListener>
    with StateDisposeScopeMixin {
  late final Player player;
  Future<void> initPlayer() async {
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    Observer(() async {
      if (widget.source.source == null) {
        return;
      }
      final source = widget.source.source!;
      if (source.source.sourcedata is! LinkSource_Mp3) {
        return;
      }
      final sourcedata = source.source.sourcedata as LinkSource_Mp3;
      final prog = source.episode.data.progress?.split(':');
      Duration startduration = Duration.zero;
      int chapterindex = 0;
      if (prog != null) {
        chapterindex = int.tryParse(prog[0]) ?? 0;
        startduration = Duration(milliseconds: int.tryParse(prog[1]) ?? 0);
      }
      await player.open(
        Playlist([
          for (final (index, chapter) in sourcedata.chapters.indexed)
            Media(
              chapter.url,
              extras: {'title': chapter.title},
              start: index == chapterindex ? startduration : Duration.zero,
            ),
        ], index: chapterindex),
      );
    }, [widget.source]);
    locate<PlayerService>().setSession(
      PlaySession(
        widget.source,
        player,
        gonext: () {
          widget.source.episode.goNext(widget.source);
        },
        goprev: () {
          widget.source.episode.goPrev(widget.source);
        },
      )..disposedBy(scope),
    );
    Observer(() {
      player.setVolume(settings.audioBookSettings.volume.value);
    }, [settings.audioBookSettings.volume]).disposedBy(scope);
    Observer(() {
      player.setRate(settings.audioBookSettings.speed.value);
    }, [settings.audioBookSettings.speed]).disposedBy(scope);
    await player.setPlaylistMode(PlaylistMode.none);

    player.stream.completed.listen((event) {
      if (!event) {
        return;
      }
      widget.source.episode.goNext(widget.source);
    });
    player.stream.position.listen((event) {
      final playlistindex = player.state.playlist.index;
      widget.source.episode.data.progress =
          '$playlistindex:${event.inMilliseconds}';
      if (event.inMilliseconds / player.state.duration.inMilliseconds > 0.5 ||
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
    final title =
        player
                .state
                .playlist
                .medias[player.state.playlist.index]
                .extras?['title']
            as String?;
    if (title == null || title == 'default') {
      return widget.source.episode.name;
    }
    return title;
  }

  Stream<void> combineStreams(List<Stream<dynamic>> streams) {
    late final StreamController<void> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    Future<void> onCancel() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }

    void onListen() {
      for (final stream in streams) {
        subscriptions.add(
          stream.listen((event) {
            controller.add(null);
          }),
        );
      }
    }

    void onPause() {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    }

    void onResume() {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
    }

    controller = StreamController<void>(
      onCancel: onCancel,
      onListen: onListen,
      onPause: onPause,
      onResume: onResume,
    );

    return controller.stream;
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
      child: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: DionImage(
                  imageUrl: widget.source.episode.cover,
                  httpHeaders: widget.source.episode.coverHeader,
                ).paddingOnly(bottom: 10),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder(
                    stream: combineStreams([
                      player.stream.duration,
                      player.stream.position,
                      player.stream.buffer,
                    ]),
                    builder: (context, snapshot) {
                      return ProgressBar(
                        progress: player.state.position,
                        total: player.state.duration,
                        buffered: player.state.buffer,
                        onSeek: (value) => player.seek(value),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DionIconbutton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () {
                          if (player.state.playlist.index == 0) {
                            if (mounted) {
                              widget.source.episode.goPrev(widget.source);
                            }
                          }
                          player.previous();
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.navigate_before),
                        onPressed: () {
                          player.seek(
                            Duration(
                              milliseconds:
                                  player.state.position.inMilliseconds - 5000,
                            ),
                          );
                        },
                      ),
                      StreamBuilder(
                        stream: player.stream.playing,
                        builder: (context, snapshot) {
                          var icon = Icons.play_arrow;
                          if (snapshot.hasData && snapshot.data!) {
                            icon = Icons.pause;
                          } else {
                            icon = Icons.play_arrow;
                          }
                          return DionIconbutton(
                            icon: Icon(icon),
                            onPressed: () async {
                              player.playOrPause();
                            },
                          );
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.navigate_next),
                        onPressed: () {
                          player.seek(
                            Duration(
                              milliseconds:
                                  player.state.position.inMilliseconds + 5000,
                            ),
                          );
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          if (player.state.playlist.index ==
                              player.state.playlist.medias.length - 1) {
                            if (mounted) {
                              widget.source.episode.goNext(widget.source);
                            }
                          }
                          player.next();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
