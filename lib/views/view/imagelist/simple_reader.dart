import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/player.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Icons, SliverAppBar;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final psettings = settings.readerSettings.imagelistreader;

class SimpleImageListReader extends StatefulWidget {
  final SourcePath source;
  final SourceSupplier supplier;
  Source_Imagelist get sourcedata => source.source as Source_Imagelist;
  const SimpleImageListReader({
    super.key,
    required this.source,
    required this.supplier,
  });

  @override
  State<SimpleImageListReader> createState() => _SimpleImageListReaderState();
}

class _SimpleImageListReaderState extends State<SimpleImageListReader>
    with StateDisposeScopeMixin {
  late final ScrollController scrollController;
  late final ListController listController;
  late final Observer supplierObserver;
  Player? player;
  bool _ctrlIsPressed = false;
  int _currentIndex = 0;
  Map<int, Future<void>> loadingMap = {};

  void play() {
    if (player == null) return;
    if (player!.state.playlist.medias.isNotEmpty &&
        player!.state.playlist.medias[0].extras!['from']! as int <
            _currentIndex &&
        player!.state.playlist.medias[0].extras!['to']! as int >
            _currentIndex) {
      return;
    }
    final audio = widget.sourcedata.audio!
        .where((e) => _currentIndex >= e.from && _currentIndex <= e.to)
        .firstOrNull;
    if (audio == null) return;
    if (player!.state.playlist.medias.isNotEmpty &&
        player!.state.playlist.medias[0].extras!['link']! as Link ==
            audio.link) {
      return;
    }
    player!.open(
      Media(
        audio.link.url,
        httpHeaders: audio.link.header,
        extras: {'from': audio.from, 'to': audio.to, 'link': audio.link},
      ),
    );
  }

  void initPlayer() {
    if (player != null) return;
    if (widget.sourcedata.audio?.isEmpty ?? true) return;
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'dion',
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.info,
      ),
    );
    locate<PlayerService>().setSession(
      PlaySession(
        widget.supplier,
        player!,
        gonext: () {
          widget.source.episode.goNext(widget.supplier);
        },
        goprev: () {
          widget.source.episode.goPrev(widget.supplier);
        },
      )..disposedBy(scope),
    );
    player!.setPlaylistMode(PlaylistMode.loop);
    player!.setVolume(psettings.volume.value);
    play();
  }

  void onScroll() {
    final epdata = widget.source.episode.data;
    SessionData.of(context)?.manager.keepSessionAlive();
    if (scrollController.hasClients &&
        scrollController.offset > 0 &&
        scrollController.position.atEdge) {
      if (epdata.finished) return;
      epdata.finished = true;
      widget.source.episode.save();
      return;
    }

    if (listController.isAttached) {
      final position = listController.unobstructedVisibleRange?.$1;
      if ((listController.visibleRange?.$2 ?? 0) >=
          widget.sourcedata.links.length / 2) {
        widget.supplier.cache.preload(widget.source.episode.next);
      }

      if (position != null && position != _currentIndex) {
        _currentIndex = position;
        if (position != 0) {
          epdata.progress = position.toString();
        }
        play();
        for (int i = 0; i < 5; i++) {
          if (loadingMap.containsKey(i + position)) {
            continue;
          }
          if (position + i >= widget.sourcedata.links.length) {
            break;
          }
          loadingMap[position + i] = DionImage.preload(
            widget.sourcedata.links[position + i].url,
            headers: widget.sourcedata.links[position + i].header,
          );
        }
      }
    }
  }

  void jumpToProgress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!listController.isAttached || !scrollController.hasClients) {
        return;
      }
      final epdata = widget.source.episode.data;
      final int pos = epdata.finished
          ? 0
          : int.tryParse(epdata.progress ?? '0') ?? 0;
      _currentIndex = pos;
      listController.jumpToItem(
        index: pos,
        alignment: 0.0,
        scrollController: scrollController,
      );
    });
  }

  @override
  void initState() {
    final epdata = widget.source.episode.data;
    _currentIndex = int.tryParse(epdata.progress ?? '0') ?? 0;

    scrollController = ScrollController(
      onAttach: (position) => jumpToProgress(),
    )..disposedBy(scope);
    listController = ListController()..disposedBy(scope);
    listController.addListener(onScroll);

    WakelockPlus.toggle(enable: true);
    Observer(() {
      if (psettings.music.value) {
        setState(() {
          initPlayer();
        });
      } else {
        setState(() {
          player?.dispose();
          player = null;
        });
      }
    }, psettings.music).disposedBy(scope);
    Observer(() {
      player?.setVolume(psettings.volume.value);
    }, psettings.volume).disposedBy(scope);

    supplierObserver = Observer(jumpToProgress, widget.supplier)
      ..disposedBy(scope);

    KeyObserver((event) {
      if (_ctrlIsPressed == HardwareKeyboard.instance.isControlPressed) return;
      setState(() {
        _ctrlIsPressed = HardwareKeyboard.instance.isControlPressed;
      });
    }).disposedBy(scope);

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    supplierObserver.swapListener(widget.supplier);
  }

  @override
  void dispose() {
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    player?.dispose();
    player = null;
    super.dispose();
  }

  Widget wrapScreen(BuildContext context, Widget child) {
    return ListenableBuilder(
      listenable: Listenable.merge([psettings.width, psettings.adaptivewidth]),
      builder: (context, child) {
        if (psettings.adaptivewidth.value && context.width < context.height) {
          return child!;
        }
        final width = context.width * (1 - (psettings.width.value / 100));
        final padding = width / 2;
        return child!.paddingOnly(left: padding, right: padding);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final images = widget.sourcedata.links;
    return NavScaff(
      showNavbar: false,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(),
        child: InteractiveViewer(
          minScale: 0.1,
          maxScale: 10,
          panAxis: PanAxis.horizontal,
          scaleEnabled: _ctrlIsPressed,
          trackpadScrollCausesScale: _ctrlIsPressed,
          child: CustomScrollView(
            controller: scrollController,
            physics: _ctrlIsPressed
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                title: DionTextScroll(widget.source.name),
                actions: [
                  if (player != null)
                    StreamBuilder(
                      stream: player!.stream.playing,
                      builder: (context, snapshot) => Stack(
                        alignment: Alignment.center,
                        fit: StackFit.passthrough,
                        children: [
                          DionIconbutton(
                            icon: Icon(
                              (snapshot.data ?? false)
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () async {
                              if (player!.state.playing) {
                                await player!.pause();
                              } else {
                                await player!.play();
                              }
                            },
                          ),
                          Positioned(
                            bottom: 0,
                            child: StreamBuilder(
                              stream: player!.stream.position,
                              builder: (context, snapshot) {
                                final position = snapshot.data ?? Duration.zero;
                                final total = player!.state.duration;
                                if (total == Duration.zero) {
                                  return const SizedBox.shrink();
                                }
                                return SizedBox(
                                  width: 24,
                                  height: 2,
                                  child: DionProgressBar(
                                    type: DionProgressType.linear,
                                    value: position.inMilliseconds.toDouble(),
                                    max: total.inMilliseconds.toDouble(),
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  DionIconbutton(
                    icon: Icon(
                      epdata.bookmark ? Icons.bookmark : Icons.bookmark_border,
                    ),
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
                    onPressed: () => context.push('/settings/imagelistreader'),
                  ),
                ],
              ),
              if (widget.source.episode.hasprev)
                SliverToBoxAdapter(
                  child: DionTextbutton(
                    child: const Text(
                      'Previous',
                    ).paddingSymmetric(vertical: 16),
                    onPressed: () =>
                        widget.source.episode.goPrev(widget.supplier),
                  ),
                ),
              SuperSliverList.builder(
                layoutKeptAliveChildren: true,
                delayPopulatingCacheArea: false,
                listController: listController,
                itemBuilder: (context, index) =>
                    wrapScreen(context, makeImage(context, images[index])),
                itemCount: images.length,
              ),
              if (widget.source.episode.hasnext)
                SliverToBoxAdapter(
                  child: DionTextbutton(
                    child: const Text('Next').paddingSymmetric(vertical: 16),
                    onPressed: () =>
                        widget.source.episode.goNext(widget.supplier),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget makeImage(BuildContext context, Link image) {
    return DionImage(
      imageUrl: image.url,
      boxFit: BoxFit.fitWidth,
      httpHeaders: image.header,
      shouldAnimate: false,
      loadingBuilder: (context) => Container(
        height: context.height * 1.2,
        color: Colors.red,
      ).applyShimmer(),
    );
  }
}
