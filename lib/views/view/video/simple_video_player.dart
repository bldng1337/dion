import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:country_flags/country_flags.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
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
  late final Player player;
  late final VideoController controller;
  late final Observer sourceObserver;
  ValueNotifier<int> subtitleIndex = ValueNotifier(0);
  Source_Video? currentVideo;
  ValueNotifier<int> streamIndex = ValueNotifier(0);
  Object? exception;

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
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
        title: 'dion',
      ),
    );
    controller = VideoController(player);
    sourceObserver = Observer(() async {
      final res = await widget.source.cache.get(widget.source.episode);
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
      if (prog != null && !source.episode.data.finished) {
        startduration = Duration(milliseconds: int.tryParse(prog[1]) ?? 0);
      }
      final stream = currentVideo!.sources[getStreamIndex()];
      await player.open(
        Media(
          stream.url.url,
          httpHeaders: stream.url.header,
          start: startduration,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      if (subtitles.isNotEmpty) {
        final sub = subtitles[subtitleIndex.value];
        await player.setSubtitleTrack(
          SubtitleTrack.uri(sub.url.url, title: sub.title),
        );
      }
    }, widget.source)..disposedBy(scope);
    Observer(
      () async {
        final startduration = player.state.position;
        final stream = currentVideo!.sources[getStreamIndex()];
        await player.open(
          Media(
            stream.url.url,
            httpHeaders: stream.url.header,
            start: startduration,
          ),
        );
      },
      streamIndex,
      callOnInit: false,
    );
    Observer(
      () async {
        if (subtitleIndex.value == -1) {
          await player.setSubtitleTrack(SubtitleTrack.no());
          return;
        }
        final sub = subtitles[subtitleIndex.value];
        await player.setSubtitleTrack(
          SubtitleTrack.uri(sub.url.url, title: sub.title),
        );
      },
      subtitleIndex,
      callOnInit: false,
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
    widget.source.episode.save();
    player.dispose();
    super.dispose();
  }

  List<Widget> getActions(bool isFullscreen) => [
    if (isFullscreen) ...[
      DionIconbutton(
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
    DionIconbutton(
      icon: Icon(
        Icons.open_in_browser,
        color: isFullscreen ? Colors.white : null,
      ),
      onPressed: () => launchUrl(Uri.parse(widget.source.episode.episode.url)),
    ),
    DionIconbutton(
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

  MaterialVideoControlsThemeData getPlayerTheme(bool isFullscreen) {
    return MaterialVideoControlsThemeData(
      topButtonBar: isFullscreen ? getActions(isFullscreen) : [],
      bottomButtonBarMargin: const EdgeInsets.all(10),
      seekBarMargin: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 60.0,
      ),
      seekBarHeight: 3.5,
      speedUpOnLongPress: true,
      primaryButtonBar: [
        if (widget.source.episode.hasprev)
          DionIconbutton(
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
    if (currentVideo == null) {
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
    return NavScaff(
      actions: getActions(false),
      title: ListenableBuilder(
        listenable: widget.source,
        builder: (context, snapshot) {
          return Text(widget.source.episode.name);
        },
      ),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          child: MaterialVideoControlsTheme(
            normal: getPlayerTheme(false),
            fullscreen: getPlayerTheme(true),
            child: Video(
              controller: controller,
              controls: MaterialVideoControls,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
