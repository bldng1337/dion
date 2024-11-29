import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
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

  void play(ImageListAudio? audio) {
    if (player == null) return;
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

  @override
  void initState() {
    final epdata = widget.source.episode.data;
    widget.sourcedata.audio;
    if (widget.sourcedata.audio?.isNotEmpty ?? false) {
      player = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.debug,
          title: 'dion',
        ),
      );
      scope.addDispose(() {
        player!.dispose();
      });
      player!.setPlaylistMode(PlaylistMode.loop);
      player!.setVolume(40);
      final audio =
          widget.sourcedata.audio!.where((e) => e.from == 0).firstOrNull;
      play(audio);
    }
    controller = ItemScrollController();
    offsetcontroller = ScrollOffsetController();
    itemPositionsListener = ItemPositionsListener.create();
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
      final int max = itemPositionsListener.itemPositions.value
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce(
            (ItemPosition max, ItemPosition position) =>
                position.itemTrailingEdge > max.itemTrailingEdge
                    ? position
                    : max,
          )
          .index;
      epdata.progress = min.toString();
      if (player != null) {
        if (player!.state.playlist.medias.isNotEmpty &&
            player!.state.playlist.medias[0].extras!['from']! as int < max &&
            player!.state.playlist.medias[0].extras!['to']! as int > max) {
          return;
        }
        final audio = widget.sourcedata.audio!
            .where((e) => max >= e.from && max <= e.to)
            .firstOrNull;
        play(audio);
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.source.episode.save();
    super.dispose();
  }

  Widget wrapScreen(BuildContext context, Widget child) {
    return child;
    // return ListenableBuilder(
    //   listenable: Listenable.merge(
    //     [
    //       // psettings.text.linewidth,
    //       // psettings.text.adaptivewidth,
    //     ],
    //   ),
    //   builder: (context, child) {
    //     if (psettings.text.adaptivewidth.value &&
    //         context.width < context.height) {
    //       return child!;
    //     }
    //     final width =
    //         context.width * (1 - (psettings.text.linewidth.value / 100));
    //     final padding = width / 2;
    //     return child!.paddingOnly(
    //       left: padding,
    //       right: padding,
    //     );
    //   },
    //   child: child,
    // );
  }

  @override
  Widget build(BuildContext context) {
    print("build");
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
          onPressed: () => context.push('/settings/paragraphreader'),
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
    );
  }
}
