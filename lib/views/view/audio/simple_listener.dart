import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart' hide TextStyle,ContainerType,CrossAxisAlignment,MainAxisAlignment,MainAxisSize,TextStyle,WrapAlignment,EdgeInsets,Alignment,StackFit,ButtonType;
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/widgets/binding_dispatcher.dart';
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
  Player? player;
  late final Observer sourceObserver;
  final List<StreamSubscription<dynamic>> playerStreamSubs = [];
  Source_Audio? currentAudio;
  final ValueNotifier<int> streamIndex = ValueNotifier(0);
  Object? exception;
  bool loading = false;

  int getStreamIndex() {
    if ((currentAudio?.sources.length ?? 0) <= streamIndex.value) {
      return 0;
    }
    return streamIndex.value;
  }

  Future<void> initPlayer() async {
    final player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    this.player = player;
    _progressStream = _buildProgressStream(player);
    sourceObserver = Observer(
      () async {
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
        final startduration = Duration(
          milliseconds: int.tryParse(source.episode.data.progress ?? '0') ?? 0,
        );
        if (mounted) {
          setState(() {
            currentAudio = source.source as Source_Audio;
          });
        }
        final stream = currentAudio!.sources[getStreamIndex()];
        logger.d(
          'Opening stream ${stream.url.url} with headers ${stream.url.header} at position $startduration',
        );
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
      widget.source,
      callIndirectly: false,
    )..disposedBy(scope);

    Observer(
      () async {
        final audio = currentAudio;
        if (audio == null) return;
        if (mounted) {
          setState(() {
            loading = true;
          });
        }
        final startduration = player.state.position;
        final stream = audio.sources[getStreamIndex()];
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
          SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
        }
      },
      streamIndex,
      callOnInit: false,
      callIndirectly: false,
    ).disposedBy(scope);

    locate<PlayerService>().setSession(
      await AudioPlayerHandler.create(
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
      settings.audioBookSettings.volume,
      callIndirectly: false,
    ).disposedBy(scope);
    Observer(
      () {
        player.setRate(settings.audioBookSettings.speed.value);
      },
      settings.audioBookSettings.speed,
      callIndirectly: false,
    ).disposedBy(scope);
    await player.setPlaylistMode(PlaylistMode.none);

    playerStreamSubs.add(
      player.stream.completed.listen((event) {
        if (!event) {
          return;
        }
        if (player.state.playlist.index <
            player.state.playlist.medias.length - 1) {
          return;
        }
        if (loading) return;
        widget.source.episode.goNext(widget.source);
      }),
    );
    playerStreamSubs.add(
      player.stream.position.listen((event) {
        if (mounted == false) return;
        if (loading) return;
        SessionData.of(context)?.manager.keepSessionAlive();
        widget.source.episode.data.progress = '${event.inMilliseconds}';
        final secs = event.inSeconds;
        if (secs != 0 && secs % 5 == 0) {
          SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
        }
        if (event.inMilliseconds / player.state.duration.inMilliseconds > 0.5) {
          widget.source.cache.preload(widget.source.episode.next);
        }
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sourceObserver.swapListener(widget.source);
  }

  @override
  void initState() {
    streamIndex.disposedBy(scope);
    initPlayer();
    super.initState();
  }

  @override
  void dispose() {
    for (final sub in playerStreamSubs) {
      sub.cancel();
    }
    _progressController?.close();
    widget.source.episode.save();
    player?.dispose();
    player = null;
    super.dispose();
  }

  Future<void> _playPause() async {
    await player?.playOrPause();
    if (!mounted) return;
    SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
  }

  void _seekBy(int milliseconds) {
    final player = this.player;
    if (player == null) return;
    final target = player.state.position + Duration(milliseconds: milliseconds);
    final duration = player.state.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > duration
        ? duration
        : target;
    player.seek(clamped);
    widget.source.episode.data.progress = '${clamped.inMilliseconds}';
    SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
  }

  void _seekForward() => _seekBy(5000);

  void _seekBackward() => _seekBy(-5000);

  void _nextChapter() {
    if (!widget.source.episode.hasnext) return;
    widget.source.episode.goNext(widget.source);
  }

  void _prevChapter() {
    if (!widget.source.episode.hasprev) return;
    widget.source.episode.goPrev(widget.source);
  }

  Future<void> _toggleBookmark() async {
    final epdata = widget.source.episode.data;
    epdata.bookmark = !epdata.bookmark;
    await widget.source.episode.save();
    if (mounted) {
      setState(() {});
    }
  }

  String getTitle(Player player) {
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

  Stream<void> _progressStream = const Stream<void>.empty();
  StreamController<void>? _progressController;

  Stream<void> _buildProgressStream(Player p) {
    final controller = StreamController<void>.broadcast();
    _progressController = controller;
    final subs = <StreamSubscription<dynamic>>[];
    void addPeers() {
      for (final stream in [
        p.stream.duration,
        p.stream.position,
        p.stream.buffer,
      ]) {
        subs.add(
          stream.listen((event) {
            if (!controller.isClosed) controller.add(null);
          }),
        );
      }
    }

    void cancelAll() {
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
    }

    controller.onListen = addPeers;
    controller.onCancel = cancelAll;
    controller.onPause = () {
      for (final s in subs) {
        s.pause();
      }
    };
    controller.onResume = () {
      for (final s in subs) {
        s.resume();
      }
    };
    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    if (exception != null) {
      return NavScaff(
        title: Text('Error loading ${widget.source.episode.name}'),
        child: ErrorDisplay(e: exception),
      );
    }
    if (currentAudio == null || player == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    final epdata = widget.source.episode.data;
    return NavScaff(
      actions: [
        DionIconbutton(
          tooltip: epdata.bookmark ? 'Remove Bookmark' : 'Add Bookmark',
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
          tooltip: 'Open in Browser',
          icon: const Icon(Icons.open_in_browser),
          onPressed: () =>
              launchUrl(Uri.parse(widget.source.episode.episode.url)),
        ),
        DionIconbutton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings/audiolistener'),
        ),
      ],
      title: StreamBuilder(
        stream: player.stream.playlist,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Text(widget.source.episode.name);
          return Text(getTitle(player));
        },
      ),
      child: BindingDispatcher(
        actions: [
          BindingAction(
            setting: settings.audioBookSettings.bindings.playPause,
            onTrigger: _playPause,
          ),
          BindingAction(
            setting: settings.audioBookSettings.bindings.seekForward,
            onTrigger: _seekForward,
          ),
          BindingAction(
            setting: settings.audioBookSettings.bindings.seekBackward,
            onTrigger: _seekBackward,
          ),
          BindingAction(
            setting: settings.audioBookSettings.bindings.nextChapter,
            onTrigger: _nextChapter,
          ),
          BindingAction(
            setting: settings.audioBookSettings.bindings.prevChapter,
            onTrigger: _prevChapter,
          ),
          BindingAction(
            setting: settings.audioBookSettings.bindings.toggleBookmark,
            onTrigger: _toggleBookmark,
          ),
        ],
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
                      stream: _progressStream,
                      builder: (context, snapshot) {
                        return Semantics(
                          label: 'Playback position',
                          value:
                              '${player.state.position.inMinutes}:${(player.state.position.inSeconds % 60).toString().padLeft(2, '0')}'
                              ' of '
                              '${player.state.duration.inMinutes}:${(player.state.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                          child: ProgressBar(
                            progress: player.state.position,
                            total: player.state.duration,
                            buffered: player.state.buffer,
                            onSeek: (value) {
                              player.seek(value);
                              widget.source.episode.data.progress =
                                  '${value.inMilliseconds}';
                              SessionData.of(
                                context,
                              )?.manager.keepSessionAlive(saveToDb: true);
                            },
                          ),
                        );
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DionIconbutton(
                          tooltip: 'Previous Chapter',
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
                          tooltip: 'Seek Backward',
                          icon: const Icon(Icons.navigate_before),
                          onPressed: _seekBackward,
                        ),
                        StreamBuilder(
                          stream: player.stream.playing,
                          initialData: player.state.playing,
                          builder: (context, snapshot) {
                            final data = snapshot.data ?? player.state.playing;
                            final icon = data ? Icons.pause : Icons.play_arrow;
                            return DionIconbutton(
                              tooltip: data ? 'Pause' : 'Play',
                              icon: Icon(icon),
                              onPressed: () async {
                                await player.playOrPause();
                                if (context.mounted) {
                                  SessionData.of(
                                    context,
                                  )?.manager.keepSessionAlive(saveToDb: true);
                                }
                              },
                            );
                          },
                        ),
                        DionIconbutton(
                          tooltip: 'Seek Forward',
                          icon: const Icon(Icons.navigate_next),
                          onPressed: _seekForward,
                        ),
                        DionIconbutton(
                          tooltip: 'Next Chapter',
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
      ),
    );
  }
}
