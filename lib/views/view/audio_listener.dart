import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:media_kit/media_kit.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class SimpleAudioListener extends StatefulWidget {
  final SourcePath source;
  LinkSource_Mp3 get sourcedata => source.source.sourcedata as LinkSource_Mp3;
  const SimpleAudioListener({super.key, required this.source});

  @override
  State<SimpleAudioListener> createState() => _SimpleImageListReaderState();
}

class _SimpleImageListReaderState extends State<SimpleAudioListener>
    with StateDisposeScopeMixin {
  late final ItemScrollController controller;
  late final ScrollOffsetController offsetcontroller;
  late final ItemPositionsListener itemPositionsListener;
  Player? player;
  Future<void> initPlayer() async {
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    await player!.setPlaylistMode(PlaylistMode.none);
    await player!.setVolume(100);
    final prog = widget.source.episode.data.progress?.split(':');
    Duration startduration = Duration.zero;
    int chapterindex = 0;
    if (prog != null) {
      chapterindex = int.tryParse(prog[0]) ?? 0;
      startduration = Duration(milliseconds: int.tryParse(prog[1]) ?? 0);
    }
    await player!.open(
      Playlist(
        [
          for (final (index, chapter) in widget.sourcedata.chapters.indexed)
            Media(
              chapter.url,
              extras: {
                'title': chapter.title,
              },
              start: index == chapterindex ? startduration : Duration.zero,
            ),
        ],
        index: chapterindex,
      ),
    );
    player!.stream.completed.listen((event) {
      if (!event) {
        return;
      }
      if (!mounted) {
        return;
      }
      widget.source.episode.goNext(context);
    });
    player!.stream.position.listen((event) {
      if (!mounted) {
        return;
      }

      final playlistindex = player!.state.playlist.index;
      // print('$playlistindex:${event.inMilliseconds}');
      widget.source.episode.data.progress =
          '$playlistindex:${event.inMilliseconds}';
      if (event.inMilliseconds / player!.state.duration.inMilliseconds > 0.5 &&
          playlistindex / player!.state.playlist.medias.length > 0.5) {
        InheritedPreload.of(context).shouldPreload();
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
    player?.dispose();
    player = null;
    super.dispose();
  }

  String getTitle() {
    final title = player!.state.playlist.medias[player!.state.playlist.index]
        .extras?['title'] as String?;
    if (title == null || title == 'default') return widget.source.name;
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
          stream.listen(
            (event) {
              controller.add(null);
            },
          ),
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
    return NavScaff(
      title: StreamBuilder(
        stream: player!.stream.playlist,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Text(widget.source.name);
          return Text(getTitle());
        },
      ),
      child: Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: widget.source.episode.episode.cover != null
                    ? DionImage(
                        imageUrl: widget.source.episode.episode.cover,
                        httpHeaders: widget.source.episode.episode.coverHeader,
                      )
                    : DionImage(
                        imageUrl: widget.source.episode.entry.cover,
                        httpHeaders: widget.source.episode.entry.coverHeader,
                      ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder(
                    stream: combineStreams([
                      player!.stream.duration,
                      player!.stream.position,
                      player!.stream.buffer,
                    ]),
                    builder: (context, snapshot) {
                      return ProgressBar(
                        progress: player!.state.position,
                        total: player!.state.duration,
                        buffered: player!.state.buffering
                            ? player!.state.buffer
                            : null,
                        onSeek: (value) => player!.seek(value),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DionIconbutton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () {
                          if (player!.state.playlist.index == 0) {
                            if (mounted) {
                              widget.source.episode.goPrev(context);
                            }
                          }
                          player!.previous();
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.navigate_before),
                        onPressed: () {
                          player!.seek(
                            Duration(
                              milliseconds:
                                  player!.state.position.inMilliseconds - 5000,
                            ),
                          );
                        },
                      ),
                      StreamBuilder(
                        stream: player!.stream.playing,
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
                              player!.playOrPause();
                            },
                          );
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.navigate_next),
                        onPressed: () {
                          player!.seek(
                            Duration(
                              milliseconds:
                                  player!.state.position.inMilliseconds + 5000,
                            ),
                          );
                        },
                      ),
                      DionIconbutton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          if (player!.state.playlist.index ==
                              player!.state.playlist.medias.length - 1) {
                            if (mounted) {
                              widget.source.episode.goNext(context);
                            }
                          }
                          player!.next();
                        },
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
