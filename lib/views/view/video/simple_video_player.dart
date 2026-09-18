import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:country_flags/country_flags.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart' hide Alignment, ButtonType, ContainerType, CrossAxisAlignment, EdgeInsets, MainAxisAlignment, MainAxisSize, StackFit, TextStyle, WrapAlignment;
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/chapters/chapter_controller.dart';
import 'package:dionysos/views/view/chapters/chapter_markers.dart';
import 'package:dionysos/views/view/chapters/chapter_sheet.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/widgets/binding_dispatcher.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';
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
  Player? player;
  VideoController? controller;
  Observer? sourceObserver;
  ChapterController? chapterController;
  final List<StreamSubscription<dynamic>> playerStreamSubs = [];
  final ValueNotifier<int> subtitleIndex = ValueNotifier(0);
  Source_Video? currentVideo;
  final ValueNotifier<int> streamIndex = ValueNotifier(0);
  Object? exception;

  bool loading = true;

  List<Subtitles> get subtitles {
    if (currentVideo == null) return [];
    return currentVideo!.sub;
  }

  int getStreamIndex() {
    if ((currentVideo?.sources.length ?? 0) <= streamIndex.value) {
      return 0;
    }
    return streamIndex.value;
  }

  Future<void> initPlayer() async {
    try {
      await _setupPlayer();
    } catch (e, s) {
      logger.e(
        'Failed to initialize video player',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        setState(() {
          exception = e;
        });
      }
    }
  }

  Future<void> _setupPlayer() async {
    final player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    this.player = player;
    controller = VideoController(player);
    chapterController = ChapterController(
      player: player,
      autoSkip: settings.videoSettings.chapters,
    )..disposedBy(scope);
    sourceObserver = Observer(() async {
      loading = true;
      final res = await widget.source.cache.get(widget.source.episode);
      if (!mounted) return;
      if (res.isFailure) {
        setState(() {
          exception = res.exceptionOrNull;
        });
        return;
      }
      final source = res.getOrThrow;
      if (source.source is! Source_Video) {
        return;
      }
      setState(() {
        currentVideo = source.source as Source_Video;
      });
      final prog = source.episode.data.progress?.split(':');
      Duration startduration = Duration.zero;
      if (prog != null &&
          prog.length > 1 &&
          !source.episode.data.finished) {
        startduration =
            Duration(milliseconds: int.tryParse(prog[1]) ?? 0);
      }
      if (currentVideo!.sources.isEmpty) {
        setState(() {
          exception = Exception('No video sources available');
        });
        return;
      }
      final stream = currentVideo!.sources[getStreamIndex()];
      await player.open(
        Media(
          stream.url.url,
          httpHeaders: stream.url.header,
          start: startduration,
        ),
      );
      unawaited(
        chapterController?.onMediaOpened(chapters: currentVideo!.chapters),
      );
      loading = false;
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (subtitles.isNotEmpty &&
          subtitleIndex.value >= 0 &&
          subtitleIndex.value < subtitles.length) {
        final sub = subtitles[subtitleIndex.value];
        await player.setSubtitleTrack(
          SubtitleTrack.uri(sub.url.url, title: sub.title),
        );
      }
    }, widget.source, callIndirectly: false)..disposedBy(scope);
    Observer(
      () async {
        final video = currentVideo;
        if (video == null) return;
        loading = true;
        final startduration = player.state.position;
        final stream = video.sources[getStreamIndex()];
        await player.open(
          Media(
            stream.url.url,
            httpHeaders: stream.url.header,
            start: startduration,
          ),
        );
        unawaited(chapterController?.onMediaOpened(chapters: video.chapters));
        loading = false;
        if (!mounted) return;
        SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
      },
      streamIndex,
      callOnInit: false,
      callIndirectly: false,
    ).disposedBy(scope);
    Observer(
      () async {
        if (subtitleIndex.value == -1) {
          await player.setSubtitleTrack(SubtitleTrack.no());
          return;
        }
        if (subtitleIndex.value < 0 ||
            subtitleIndex.value >= subtitles.length) {
          return;
        }
        final sub = subtitles[subtitleIndex.value];
        await player.setSubtitleTrack(
          SubtitleTrack.uri(sub.url.url, title: sub.title),
        );
      },
      subtitleIndex,
      callOnInit: false,
    ).disposedBy(scope);
    final handler = await AudioPlayerHandler.create(
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
    );
    if (!mounted) {
      // The view was disposed while the handler was being created;
      // disposing it detaches its listener from the long-lived source
      // supplier instead of leaking it (disposedBy would throw here).
      await handler.dispose();
      return;
    }
    locate<PlayerService>().setSession(handler..disposedBy(scope));
    Observer(() {
      player.setVolume(settings.videoSettings.volume.value);
    }, settings.videoSettings.volume).disposedBy(scope);
    Observer(() {
      player.setRate(settings.videoSettings.speed.value);
    }, settings.videoSettings.speed).disposedBy(scope);
    await player.setPlaylistMode(PlaylistMode.none);
    if (!mounted) return;

    playerStreamSubs.add(
      player.stream.completed.listen((event) {
        if (!event) {
          return;
        }
        if (!mounted) {
          return;
        }
        widget.source.episode.goNext(widget.source);
      }),
    );
    playerStreamSubs.add(
      player.stream.playing.listen((_) {
        if (!mounted) return;
        SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
      }),
    );
    playerStreamSubs.add(
      player.stream.position.listen((event) {
        if (!mounted) {
          return;
        }
        if (loading) return;
        SessionData.of(context)?.manager.keepSessionAlive();
        final playlistindex = player.state.playlist.index;
        widget.source.episode.data.progress =
            '$playlistindex:${event.inMilliseconds}';
        final duration = player.state.duration;
        if (duration > Duration.zero &&
            event.inMilliseconds / duration.inMilliseconds > 0.5) {
          widget.source.cache.preload(widget.source.episode.next);
        }
        if (event.inSeconds % 5 == 0) {
          SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
        }
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sourceObserver?.swapListener(widget.source);
  }

  @override
  void initState() {
    subtitleIndex.disposedBy(scope);
    streamIndex.disposedBy(scope);
    initPlayer();
    super.initState();
  }

  @override
  void dispose() {
    for (final sub in playerStreamSubs) {
      sub.cancel();
    }
    widget.source.episode.save();
    player?.dispose();
    player = null;
    super.dispose();
  }

  Future<void> _nextChapter() async {
    if (chapterController != null && await chapterController!.nextChapter()) {
      return;
    }
    if (widget.source.episode.hasnext) {
      widget.source.episode.goNext(widget.source);
    }
  }

  Future<void> _prevChapter() async {
    if (chapterController != null && await chapterController!.prevChapter()) {
      return;
    }
    if (widget.source.episode.hasprev) {
      widget.source.episode.goPrev(widget.source);
    }
  }

  Future<void> _toggleBookmark() async {
    widget.source.episode.data.bookmark =
        !widget.source.episode.data.bookmark;
    await widget.source.episode.save();
    if (mounted) {
      setState(() {});
    }
  }

  List<Widget> getActions(bool isFullscreen) => [
    if (isFullscreen) ...[
      DionIconbutton(
        tooltip: 'Back',
        onPressed: () {
          exitFullscreen(context);
          GoRouter.of(context).pop();
        },
        icon: Icon(Icons.arrow_back, color: isFullscreen ? Colors.white : null),
      ),
      ListenableBuilder(
        listenable: widget.source,
        builder: (context, snapshot) {
          return Text(
            widget.source.episode.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          );
        },
      ).paddingOnly(left: 10),
      const Spacer(),
    ],
    StatefulBuilder(
      builder: (context, setState) => DionIconbutton(
        tooltip:
            widget.source.episode.data.bookmark
                ? 'Remove Bookmark'
                : 'Add Bookmark',
        icon: Icon(
          widget.source.episode.data.bookmark
              ? Icons.bookmark
              : Icons.bookmark_border,
          color: isFullscreen ? Colors.white : null,
        ),
        onPressed: () async {
          widget.source.episode.data.bookmark =
              !widget.source.episode.data.bookmark;
          await widget.source.episode.save();
          if (mounted) {
            setState(() {});
          }
        },
      ),
    ),
    ListenableBuilder(
      listenable: chapterController!,
      builder: (context, _) {
        if (!chapterController!.hasChapters) {
          return const SizedBox.shrink();
        }
        return DionIconbutton(
          tooltip: 'Chapters',
          icon: Icon(
            Icons.format_list_numbered,
            color: isFullscreen ? Colors.white : null,
          ),
          onPressed: () => showChapterSheet(context, chapterController!),
        );
      },
    ),
    DionIconbutton(
      tooltip: 'Open in Browser',
      icon: Icon(
        Icons.open_in_browser,
        color: isFullscreen ? Colors.white : null,
      ),
      onPressed: () => launchUrl(Uri.parse(widget.source.episode.episode.url)),
    ),
    DionIconbutton(
      tooltip: 'Settings',
      icon: Icon(Icons.settings, color: isFullscreen ? Colors.white : null),
      onPressed: () => GoRouter.of(context).push('/settings/videoplayer'),
    ),
    if (currentVideo!.sources.length > 1)
      DionDropdown(
        value: getStreamIndex(),
        items: currentVideo!.sources.indexed
            .map(
              (item) => DionDropdownItemWidget(
                value: item.$1,
                label: '${item.$2.name} (${item.$2.lang})',
                labelWidget: Row(
                  children: [
                    CountryFlag.fromLanguageCode(
                      item.$2.lang,
                      height: 16,
                      width: 16,
                    ),
                    5.widthBox,
                    Text(item.$2.name),
                  ],
                ),
                selectedItemWidget: Row(
                  children: [
                    CountryFlag.fromLanguageCode(
                      item.$2.lang,
                      height: 16,
                      width: 16,
                    ),
                    5.widthBox,
                    Text(
                      item.$2.name,
                      style: TextStyle(
                        color: isFullscreen ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          streamIndex.value = value;
        },
      ).paddingOnly(right: 10, left: 2),
    if (subtitles.isNotEmpty)
      DionDropdown<int>(
        value: subtitleIndex.value,
        items: [
          DionDropdownItemWidget(
            value: -1,
            label: 'No subtitles',
            labelWidget: Row(
              children: [
                const Icon(Icons.close, size: 16),
                5.widthBox,
                const Text('No subtitles'),
              ],
            ),
            selectedItemWidget: Row(
              children: [
                Icon(
                  Icons.close,
                  size: 16,
                  color: isFullscreen ? Colors.white : null,
                ),
                5.widthBox,
                Text(
                  'No subtitles',
                  style: TextStyle(color: isFullscreen ? Colors.white : null),
                ),
              ],
            ),
          ),
          ...subtitles.indexed.map((item) {
            final hasIcon = FlagCode.fromLanguageCode(item.$2.lang) != null;
            return DionDropdownItemWidget(
              value: item.$1,
              label: item.$2.title,
              labelWidget: Row(
                children: [
                  if (hasIcon)
                    CountryFlag.fromLanguageCode(
                      item.$2.lang,
                      height: 16,
                      width: 16,
                    )
                  else
                    const Icon(Icons.subtitles, size: 16),
                  5.widthBox,
                  Text(item.$2.title),
                ],
              ),
              selectedItemWidget: Row(
                children: [
                  if (hasIcon)
                    CountryFlag.fromLanguageCode(
                      item.$2.lang,
                      height: 16,
                      width: 16,
                    )
                  else
                    const Icon(Icons.subtitles, size: 16),
                  5.widthBox,
                  Text(
                    item.$2.title,
                    style: TextStyle(color: isFullscreen ? Colors.white : null),
                  ),
                ],
              ),
            );
          }),
        ],
        onChanged: (value) {
          if (value == null) return;
          subtitleIndex.value = value;
        },
      ),
  ];

  /// Layout of the built-in seek bar and bottom bar. Single source of truth
  /// for both the controls theme and the chapter overlay drawn on top of it.
  static const double _seekBarSideInset = 16.0;
  static const double _seekBarBottom = 60.0;
  static const double _seekBarHeight = 3.5;
  // Small enough that the seek bar's touch container hugs the visible bar
  // instead of reaching ~32px above it (the media_kit default of 36).
  static const double _seekBarContainerHeight = 18.0;
  static const double _barRowEdge = 10.0;
  static const double _barRowHeight = 56.0;

  MaterialVideoControlsThemeData getPlayerTheme(bool isFullscreen) {
    final player = this.player!;
    return MaterialVideoControlsThemeData(
      topButtonBar: isFullscreen ? getActions(isFullscreen) : [],
      bottomButtonBarMargin: const EdgeInsets.all(_barRowEdge),
      seekBarMargin: const EdgeInsets.only(
        left: _seekBarSideInset,
        right: _seekBarSideInset,
        bottom: _seekBarBottom,
      ),
      seekBarHeight: _seekBarHeight,
      seekBarContainerHeight: _seekBarContainerHeight,
      speedUpOnLongPress: true,
      // The chapter overlay draws onto the seek bar from the bottom button
      // bar row; its geometry mirrors the margins above. The overlay must be
      // the row's only flex child, so the fullscreen button rides inside it.
      bottomButtonBar: [
        ChapterSeekbarOverlay(
          controller: chapterController!,
          trailing: const MaterialFullscreenButton(),
          geometry: const SeekbarGeometry(
            seekBarMargin: EdgeInsets.only(
              left: _seekBarSideInset,
              right: _seekBarSideInset,
              bottom: _seekBarBottom,
            ),
            seekBarHeight: _seekBarHeight,
            buttonBarMargin: EdgeInsets.all(_barRowEdge),
            buttonBarHeight: _barRowHeight,
          ),
        ),
      ],
      primaryButtonBar: [
        if (widget.source.episode.hasprev)
          DionIconbutton(
            tooltip: 'Previous Episode',
            icon: const Icon(
              Icons.skip_previous,
              size: 35,
              color: Colors.white,
            ),
            onPressed: () {
              widget.source.episode.goPrev(widget.source);
            },
          ).paddingAll(25.0)
        else
          85.widthBox,
        StreamBuilder(
          stream: player.stream.playing,
          builder: (context, snapshot) => DionIconbutton(
            tooltip:
                (snapshot.data ?? player.state.playing) ? 'Pause' : 'Play',
            icon: Icon(
              snapshot.data ?? player.state.playing
                  ? Icons.pause
                  : Icons.play_arrow,
              size: 35,
              color: Colors.white,
            ),
            onPressed: () async {
              await player.playOrPause();
            },
          ),
        ).paddingAll(25.0),
        if (widget.source.episode.hasnext)
          DionIconbutton(
            tooltip: 'Next Episode',
            icon: const Icon(Icons.skip_next, size: 35, color: Colors.white),
            onPressed: () {
              widget.source.episode.goNext(widget.source);
            },
          ).paddingAll(25.0)
        else
          85.widthBox,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final controller = this.controller;
    if (exception != null) {
      return NavScaff(
        title: Text('Error loading ${widget.source.episode.name}'),
        child: ErrorDisplay(e: exception),
      );
    }
    if (currentVideo == null || player == null || controller == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return NavScaff(
      actions: getActions(false),
      title: ListenableBuilder(
        listenable: widget.source,
        builder: (context, snapshot) {
          return Text(widget.source.episode.name);
        },
      ),
      child: BindingDispatcher(
        actions: [
          BindingAction(
            setting: settings.videoSettings.bindings.nextChapter,
            onTrigger: _nextChapter,
          ),
          BindingAction(
            setting: settings.videoSettings.bindings.prevChapter,
            onTrigger: _prevChapter,
          ),
          BindingAction(
            setting: settings.videoSettings.bindings.toggleBookmark,
            onTrigger: _toggleBookmark,
          ),
        ],
        child: Center(
          // Size to the largest 16:9 box that fits the available area; a
          // fixed width-derived height overflows (clipping the controls) in
          // wide, short desktop windows.
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: MaterialVideoControlsTheme(
              normal: getPlayerTheme(false),
              fullscreen: getPlayerTheme(true),
              child: Video(
                controller: controller,
                controls: _buildControls,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps the built-in controls with the chapter skip pill, placed above the
  /// seek bar. It lives outside the controls themselves so it stays visible
  /// while they are hidden.
  Widget _buildControls(VideoState state) {
    return Stack(
      children: [
        Positioned.fill(child: MaterialVideoControls(state)),
        Positioned(
          right: _seekBarSideInset,
          bottom:
              _seekBarBottom + _seekBarContainerHeight + DionSpacing.sm,
          child: ChapterSkipButton(controller: chapterController!),
        ),
      ],
    );
  }
}
