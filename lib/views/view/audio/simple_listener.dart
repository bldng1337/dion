import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';
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
  late final Observer sourceObserver;
  Source_Audio? currentAudio;
  ValueNotifier<int> streamIndex = ValueNotifier(0);
  Object? exception;
  bool loading = false;

  int getStreamIndex() {
    if ((currentAudio?.sources.length ?? 0) <= streamIndex.value) {
      return 0;
    }
    return streamIndex.value;
  }

  Future<void> initPlayer() async {
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    sourceObserver = Observer(() async {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }
      final res = await widget.source.cache.get(widget.source.episode);
      if (res.isFailure) {
        if (mounted) {
          setState(() {
            exception = res.exceptionOrNull;
          });
        }
        return;
      }
      final source = res.getOrThrow;
      if (source.source is! Source_Audio) {
        if (mounted) {
          setState(() {
            exception = Exception(
              'Unexpected Type Expected Source_Audio got ${source.source.runtimeType}',
            );
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          currentAudio = source.source as Source_Audio;
        });
      }
      final startduration = Duration(
        milliseconds: int.tryParse(source.episode.data.progress ?? '0') ?? 0,
      );
      final stream = currentAudio!.sources[getStreamIndex()];
      await player.open(
        Media(
          stream.url.url,
          httpHeaders: stream.url.header,
          start: startduration,
        ),
      );
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }, widget.source)..disposedBy(scope);

    Observer(
      () async {
        if (mounted) {
          setState(() {
            loading = true;
          });
        }
        final startduration = player.state.position;
        final stream = currentAudio!.sources[getStreamIndex()];
        await player.open(
          Media(
            stream.url.url,
            httpHeaders: stream.url.header,
            start: startduration,
          ),
        );
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
      },
      streamIndex,
      callOnInit: false,
    );

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
    }, settings.audioBookSettings.volume).disposedBy(scope);
    Observer(() {
      player.setRate(settings.audioBookSettings.speed.value);
    }, settings.audioBookSettings.speed).disposedBy(scope);
    await player.setPlaylistMode(PlaylistMode.none);

    player.stream.completed.listen((event) {
      if (!event) {
        return;
      }
      if (player.state.playlist.index <
          player.state.playlist.medias.length - 1) {
        return;
      }
      widget.source.episode.goNext(widget.source);
    });
    player.stream.position.listen((event) {
      widget.source.episode.data.progress = '${event.inMilliseconds}';
      if (event.inMilliseconds / player.state.duration.inMilliseconds > 0.5) {
        widget.source.cache.preload(widget.source.episode.next);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sourceObserver.swapListener(widget.source);
  }

  @override
  void initState() {
    initPlayer();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    widget.source.episode.save();
    player.dispose();
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
    if (currentAudio == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    if (exception != null) {
      return NavScaff(
        title: Text('Error loading ${widget.source.episode.name}'),
        child: ErrorDisplay(e: exception),
      );
    }
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
                  imageUrl: widget.source.episode.cover?.url,
                  httpHeaders: widget.source.episode.cover?.header,
                ).paddingOnly(bottom: 10),
              ),
            ),
            if (loading)
              50.0.heightBox
            else
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
                          initialData: player.state.playing,
                          builder: (context, snapshot) {
                            final data = snapshot.data ?? player.state.playing;
                            final icon = data ? Icons.pause : Icons.play_arrow;
                            return DionIconbutton(
                              icon: Icon(icon),
                              onPressed: () async {
                                await player.playOrPause();
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
                        if (currentAudio!.sources.length > 1)
                          DionDropdown(
                            items: currentAudio!.sources.indexed
                                .map(
                                  (item) => DionDropdownItem(
                                    value: item.$1,
                                    label: '${item.$2.name} (${item.$2.lang})',
                                  ),
                                )
                                .toList(),
                            value: getStreamIndex(),
                            onChanged: (val) {
                              if (val == null) return;
                              streamIndex.value = val;
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
