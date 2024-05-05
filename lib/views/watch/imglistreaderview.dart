import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:dionysos/widgets/hugelist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:huge_listview/huge_listview.dart' as huge;
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';
//TODO: Work in progress
class Imglistreader extends StatefulWidget {
  final ImgListSource source;
  const Imglistreader(this.source, {super.key});

  @override
  _ImglistreaderState createState() => _ImglistreaderState();
}

class _ImglistreaderState extends State<Imglistreader> {
  ImgListSource? source;
  final LruMap<int, huge.HugeListViewPageResult<Source?>> map =
      LruMap(maximumSize: 3);
  int currchap = 0;

  @override
  void initState() {
    source = widget.source;
    currchap = widget.source.getIndex();
    super.initState();
  }

  void scrollUp() {
    scoffset.animateScroll(
        offset: -400, duration: const Duration(milliseconds: 100),);
  }

  void scrollDown() {
    scoffset.animateScroll(
        offset: 400, duration: const Duration(milliseconds: 100),);
  }

  void bookmark() {
    setState(() {
      widget.source.getEpdata().isBookmarked =
          !widget.source.getEpdata().isBookmarked;
    });
  }

  void openwebview() {
    launchUrl(Uri.parse(source?.ep.url ?? ''));
  }

  ScrollOffsetController scoffset = ScrollOffsetController();
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): scrollUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): scrollDown,
        const SingleActivator(LogicalKeyboardKey.keyW): scrollUp,
        const SingleActivator(LogicalKeyboardKey.keyS): scrollDown,
        const SingleActivator(LogicalKeyboardKey.keyE): bookmark,
        const SingleActivator(LogicalKeyboardKey.keyQ): openwebview,
      },
      child: Scaffold(
        appBar: AppBar(
            title: Row(
              children: [Text(source?.ep.name ?? 'Loading...')],
            ),
            actions: [
              IconButton(
                  onPressed: openwebview, icon: const Icon(Icons.web_outlined),),
              IconButton(
                  icon: Icon(source?.getEpdata().isBookmarked ?? false
                      ? Icons.bookmark
                      : Icons.bookmark_outline,),
                  onPressed: bookmark,),
              IconButton(
                  onPressed: () => enav(context,
                      mangareadersettings.build(() => setState(() {})),),
                  icon: const Icon(Icons.settings),),
            ],),
        body: HugeListView(
          scrollOffsetController: scoffset,
          pageSize: 1,
          firstShown: (value) {
            if (currchap == value) {
              return;
            }
            if (value > currchap) {
              if (source != null) {
                source!.entry.complete(source!.getIndex());
              }
              source?.entry.save();
            }
            setState(() {
              currchap = value;
              source = map[value]?.items.first as ImgListSource?;
            });
            if (source == null) {
              currchap = -1;
            }
          },
          startIndex: widget.source.getIndex(),
          pageFuture: (index) async {
            return [(await widget.source.getByIndex(index))];
          },
          thumbBuilder: huge.DraggableScrollbarThumbs.SemicircleThumb,
          itemBuilder: (context, index, Source? entry) {
            if (entry == null) {
              return Text('Error $index');
            }
            return ImgList(
              source: entry as ImgListSource,
            );
          },
          placeholderBuilder: (build, index) => SizedBox(
            height: MediaQuery.of(context).size.height,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          lruMap: map,
        ),
      ),
    );
  }
}

class ImgList extends StatefulWidget {
  final ImgListSource source;
  const ImgList({super.key, required this.source});

  @override
  _ImgListState createState() => _ImgListState();
}

class _ImgListState extends State<ImgList> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double edge = (MediaQuery.of(context).size.width -
            ((MangareaderSetting.imagewidth.value / 100) *
                MediaQuery.of(context).size.width)) /
        2;
    if (isVertical(context)) {
      edge = 0;
    }
    return Padding(
      padding: EdgeInsets.only(left: edge, right: edge),
      child: ScrollablePositionedList.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemBuilder: (context, i) {
          return CachedNetworkImage(
            filterQuality: FilterQuality.high,
            fit: BoxFit.fitWidth,
            imageUrl: widget.source.urls[i],
            progressIndicatorBuilder: (context, url, downloadProgress) =>
                SizedBox(
              height: MediaQuery.of(context).size.height,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          );
        },
        initialScrollIndex: max(widget.source.getEpdata().iprogress??0, 0),
        itemCount: widget.source.urls.length,
      ),
    );
  }
}







class PaginatedImgListViewer extends StatefulWidget {
  final ImgListSource source;
  final bool local;
  const PaginatedImgListViewer(this.source, {super.key, this.local = false});

  @override
  State<PaginatedImgListViewer> createState() => _PaginatedImgListViewerState();
}

class _PaginatedImgListViewerState extends State<PaginatedImgListViewer> {
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    save();
    super.dispose();
  }

  void save() {
    final int min = itemPositionsListener.itemPositions.value
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .reduce((ItemPosition min, ItemPosition position) =>
            position.itemTrailingEdge < min.itemTrailingEdge ? position : min,)
        .index;
    widget.source.getEpdata().iprogress = min;
    widget.source.entry.save();
  }

  Future<void> navPreviousChapter() async {
    if (!mounted) {
      return;
    }
    if (!widget.source.hasPrevious()) {
      return;
    }
    if (nav) {
      return;
    }
    nav = true;
    navreplaceSource(context, widget.source.getPrevious());
  }

  bool nav = false;
  Future<void> navNextChapter() async {
    if (!mounted) {
      return;
    }
    if (!widget.source.hasNext()) {
      return;
    }
    if (nav) {
      return;
    }
    nav = true;
    navreplaceSource(context, widget.source.getNext());
    widget.source.entry.complete(widget.source.getIndex());
    widget.source.entry.save();
  }

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 15), (timer) => save());
    super.initState();
  }

  void scrollDown() {
    sc.animateScroll(offset: 200, duration: const Duration(milliseconds: 200));
  }

  void scrollUp() {
    sc.animateScroll(offset: -200, duration: const Duration(milliseconds: 200));
  }

  void bookmark() {
    setState(() {
      widget.source.getEpdata().isBookmarked =
          !widget.source.getEpdata().isBookmarked;
    });
  }

  void openwebview() {
    launchUrl(Uri.parse(widget.source.ep.url));
  }

  ItemScrollController sci = ItemScrollController();
  ScrollOffsetController sc = ScrollOffsetController();
  ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  @override
  Widget build(BuildContext context) {
    double edge = (MediaQuery.of(context).size.width -
            ((MangareaderSetting.imagewidth.value / 100) *
                MediaQuery.of(context).size.width)) /
        2;
    if (MangareaderSetting.adaptivewidth.value && isVertical(context)) {
      edge = 0.0;
    }
    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): scrollUp,
          const SingleActivator(LogicalKeyboardKey.arrowDown): scrollDown,
          const SingleActivator(LogicalKeyboardKey.arrowRight): navNextChapter,
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              navPreviousChapter,
          const SingleActivator(LogicalKeyboardKey.keyW): scrollUp,
          const SingleActivator(LogicalKeyboardKey.keyS): scrollDown,
          const SingleActivator(LogicalKeyboardKey.keyE): bookmark,
          const SingleActivator(LogicalKeyboardKey.keyQ): openwebview,
          const SingleActivator(LogicalKeyboardKey.keyD): navNextChapter,
          const SingleActivator(LogicalKeyboardKey.keyA): navPreviousChapter,
        },
        child: GestureDetector(
          onDoubleTap: () {
            bookmark();
          },
          onHorizontalDragUpdate: (details) {
            const int sensitivity = 8;
            if (details.delta.dx > sensitivity) {
              navPreviousChapter();
            } else if (details.delta.dx < -sensitivity) {
              navNextChapter();
            }
          },
          child: Scaffold(
            appBar: AppBar(
                leading: ExcludeFocus(
                    child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.pop();
                  },
                ),),
                title: Text(widget.source.ep.name),
                actions: [
                  IconButton(
                      autofocus: true,
                      onPressed: openwebview,
                      icon: const Icon(Icons.web_outlined),),
                  IconButton(
                      icon: Icon(widget.source.getEpdata().isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_outline,),
                      onPressed: bookmark,),
                  IconButton(
                      onPressed: () => enav(context,
                          mangareadersettings.build(() => setState(() {})),),
                      icon: const Icon(Icons.settings),),
                ],),
            body: ScrollablePositionedList.builder(
              scrollOffsetController: sc,
              itemScrollController: sci,
              itemPositionsListener: itemPositionsListener,
              itemBuilder: (context, i) {
                if (i == 0) {
                  if (widget.source.hasPrevious()) {
                    return ExcludeFocus(
                        child: TextButton(
                      onPressed: () {
                        navPreviousChapter();
                      },
                      child: const Text('Previous Chapter'),
                    ),);
                  }
                } else if (i <= widget.source.urls.length) {
                  return Padding(
                      padding: EdgeInsets.only(left: edge, right: edge),
                      child: image(widget.source.urls[i - 1]),);
                } else {
                  if (widget.source.hasNext()) {
                    return ExcludeFocus(
                        child: TextButton(
                      onPressed: () {
                        navNextChapter();
                      },
                      child: const Text('Next Chapter'),
                    ),);
                  } else {
                    widget.source.entry.complete(widget.source.getIndex());
                    widget.source.entry.save();
                  }
                }
                return Container();
              },
              initialScrollIndex:
                  max(widget.source.getEpdata().iprogress??0, 0),
              itemCount: widget.source.urls.length + 2,
            ),
          ),
        ),);
  }

  Widget image(String path) {
    if (widget.local) {
      return Image.file(
        File(path),
        filterQuality: FilterQuality.high,
        fit: BoxFit.fitWidth,
      );
    }
    return CachedNetworkImage(
      filterQuality: FilterQuality.high,
      fit: BoxFit.fitWidth,
      imageUrl: path,
      progressIndicatorBuilder: (context, url, downloadProgress) => SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Center(
          child: CircularProgressIndicator(
            value: downloadProgress.progress,
          ),
        ),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error),
    );
  }
}
