import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:url_launcher/url_launcher.dart';

final psettings = settings.readerSettings.imagelistreader;

class SimpleImageListReader extends StatefulWidget {
  final SourcePath source;
  LinkSource_Imagelist get sourcedata =>
      source.source.sourcedata as LinkSource_Imagelist;
  const SimpleImageListReader({super.key, required this.source});

  @override
  State<SimpleImageListReader> createState() => _SimpleImageListReaderState();
}

class _SimpleImageListReaderState extends State<SimpleImageListReader>
    with StateDisposeScopeMixin {
  late final ItemScrollController controller;
  late final ScrollOffsetController offsetcontroller;
  late final ItemPositionsListener itemPositionsListener;
  Player? player;

  void play() {
    if (player == null) return;
    final int max = itemPositionsListener.itemPositions.value
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .fold(
          const ItemPosition(index: 0, itemTrailingEdge: 0, itemLeadingEdge: 0),
          (ItemPosition max, ItemPosition position) =>
              position.itemTrailingEdge > max.itemTrailingEdge ? position : max,
        )
        .index;
    if (player!.state.playlist.medias.isNotEmpty &&
        player!.state.playlist.medias[0].extras!['from']! as int < max &&
        player!.state.playlist.medias[0].extras!['to']! as int > max) {
      return;
    }
    final audio = widget.sourcedata.audio!
        .where((e) => max >= e.from && max <= e.to)
        .firstOrNull;
    if (audio == null) return;
    player!.open(
      Media(
        audio.link,
        // httpHeaders: widget.sourcedata.header,
        extras: {
          'from': audio.from,
          'to': audio.to,
          'link': audio.link,
        },
      ),
    );
  }

  void initPlayer() {
    if (player != null) return;
    if (widget.sourcedata.audio?.isEmpty ?? true) return;
    player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.debug,
        title: 'dion',
      ),
    );
    player!.setPlaylistMode(PlaylistMode.loop);
    player!.setVolume(psettings.volume.value);
    play();
  }

  @override
  void initState() {
    final epdata = widget.source.episode.data;
    controller = ItemScrollController();
    offsetcontroller = ScrollOffsetController();
    itemPositionsListener = ItemPositionsListener.create();
    Observer(
      () {
        logger.i('Music ${psettings.music.value}');
        if (psettings.music.value) {
          initPlayer();
        } else {
          player?.dispose();
          player = null;
        }
      },
      [psettings.music],
    ).disposedBy(scope);
    Observer(
      () {
        logger.i('Volume ${psettings.volume.value}');
        player?.setVolume(psettings.volume.value);
      },
      [psettings.volume],
    ).disposedBy(scope);
    if (psettings.music.value) {
      initPlayer();
    }
    itemPositionsListener.itemPositions.addListener(() {
      final int min = itemPositionsListener.itemPositions.value
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce(
            (ItemPosition min, ItemPosition position) =>
                position.itemTrailingEdge < min.itemTrailingEdge
                    ? position
                    : min,
          )
          .index;
      epdata.progress = min.toString();
      play();
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.source.episode.save();
    player?.dispose();
    player = null;
    super.dispose();
  }

  Widget wrapScreen(BuildContext context, Widget child) {
    return ListenableBuilder(
      listenable: Listenable.merge(
        [
          psettings.width,
          psettings.adaptivewidth,
        ],
      ),
      builder: (context, child) {
        if (psettings.adaptivewidth.value && context.width < context.height) {
          return child!;
        }
        final width = context.width * (1 - (psettings.width.value / 100));
        final padding = width / 2;
        return child!.paddingOnly(
          left: padding,
          right: padding,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final images = widget.sourcedata.links;
    return NavScaff(
      title: TextScroll(widget.source.name),
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
          onPressed: () => context.push('/settings/imagelistreader'),
        ),
      ],
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ScrollablePositionedList.builder(
          physics: const ClampingScrollPhysics(),
          scrollOffsetController: offsetcontroller,
          itemScrollController: controller,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: int.tryParse(epdata.progress ?? '0') ?? 0,
          minCacheExtent: 12,
          itemBuilder: (context, index) {
            if (index == 0) {
              if (widget.source.episode.hasprev) {
                return DionTextbutton(
                  child: const Text('Previous'),
                  onPressed: () => widget.source.episode.goPrev(context),
                );
              }
              return nil;
            }
            if (index - 1 == images.length) {
              if (widget.source.episode.hasnext) {
                return DionTextbutton(
                  child: const Text('Next'),
                  onPressed: () => widget.source.episode.goNext(context),
                );
              }
              return nil;
            }
            return wrapScreen(
              context,
              makeImage(context, images[index - 1]),
            );
          },
          itemCount: images.length + 2,
        ),
      ),
    );
  }

  Widget makeImage(BuildContext context, String image) {
    // return Container(
    //   width: context.width,
    //   height: context.height,
    //   color: Colors.red,
    //   // child: DionImage(
    //   //   imageUrl: image,
    //   //   boxFit: BoxFit.fitWidth,
    //   //   httpHeaders: widget.sourcedata.header,
    //   // ),
    // );
    return DionImage(
      imageUrl: image,
      boxFit: BoxFit.fitWidth,
      httpHeaders: widget.sourcedata.header,
      shouldAnimate: false,
      loadingBuilder: (context) => Container(
        height: context.height*2,
        color: Colors.red,
      ).applyShimmer(),
    );
  }
}
