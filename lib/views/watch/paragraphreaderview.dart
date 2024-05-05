import 'dart:async';
import 'dart:math';

import 'package:bionify/bionify.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:dionysos/widgets/hugelist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:huge_listview/huge_listview.dart' as hlist;
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';

Widget toText(BuildContext context, String paragraph) {
  final avg = TextStyle(
    fontSize: TextReaderSettings.textsize.value,
    color: Theme.of(context).textTheme.displaySmall?.color,
    fontWeight: FontWeight.values.firstWhere((element) =>
        element.toString().contains(TextReaderSettings.textweight.value),),
  );
  if (TextReaderSettings.bionic.value) {
    return Bionify(
      ratio: TextReaderSettings.bionicpercent.value,
      content: paragraph,
      basicStyle: avg,
      markStyle: TextStyle(
        fontSize: TextReaderSettings.textsize.value,
        color: Theme.of(context).textTheme.displaySmall?.color,
        fontWeight: FontWeight.values.firstWhere((element) => element
            .toString()
            .contains(TextReaderSettings.bionichighlight.value),),
      ),
    );
  }
  return Text(
    paragraph,
    style: avg,
  );
}

//Infinity Scroll
class Paragraphreader extends StatefulWidget {
  final ParagraphListSource source;
  const Paragraphreader({super.key, required this.source});

  @override
  _ParagraphreaderState createState() => _ParagraphreaderState();
}

class _ParagraphreaderState extends State<Paragraphreader> {
  ParagraphListSource? source;
  final LruMap<int, hlist.HugeListViewPageResult<Source?>> map =
      LruMap(maximumSize: 3);
  int currchap = 0;
  @override
  void initState() {
    source = widget.source;
    currchap = widget.source.getIndex();
    // sc.animateScroll(offset: 0,duration: Duration(microseconds: 100));
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
    launchUrl(Uri.parse(source?.ep.url ?? ''));
  }

  void back(BuildContext context) {}

  ScrollOffsetController sc = ScrollOffsetController();
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
            title: Text(
              source?.ep.name ?? 'Loading...',
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
                  onPressed: () => enav(
                      context, textreadersettings.build(() => setState(() {})),),
                  icon: const Icon(Icons.settings),),
            ],),
        body: HugeListView(
          scrollOffsetController: sc,
          pageSize: 1,
          firstShown: (value) {
            if (currchap == value) {
              return;
            }
            if (value > currchap) {
              source!.entry.complete(source!.getIndex());
              source?.entry.save();
            }
            setState(() {
              currchap = value;
              source = map[value]?.items.first as ParagraphListSource?;
            });
            if (source == null) {
              currchap = -1;
            }
          },
          startIndex: widget.source.getIndex(),
          pageFuture: (index) async {
            return [(await widget.source.getByIndex(index))];
          },
          thumbBuilder: hlist.DraggableScrollbarThumbs.SemicircleThumb,
          itemBuilder: (context, index, Source? entry) {
            if (entry == null) {
              return Text('Error $index');
            }
            return Paragraph(
              source: entry as ParagraphListSource,
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

class Paragraph extends StatelessWidget {
  final ParagraphListSource source;
  const Paragraph({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final double edge = (MediaQuery.of(context).size.width -
            ((TextReaderSettings.textwidth.value / 100) *
                MediaQuery.of(context).size.width)) /
        2;
    return Padding(
      padding: EdgeInsets.only(left: edge, right: edge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.ep.name,
            style: const TextStyle(
              fontSize: 40,
            ),
          ),
          ...source.paragraphs.map((e) => toText(context, e)),
        ],
      ),
    );
  }
}

//Paginated Reader
class ParagraphReader extends StatefulWidget {
  final ParagraphListSource source;
  const ParagraphReader({super.key, required this.source});

  @override
  State<ParagraphReader> createState() => _ParagraphReaderState();
}

class _ParagraphReaderState extends State<ParagraphReader> {
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
    // Source? prev = await widget.source.getPrevious();
    // if (!mounted) {
    //   nav = false;
    //   return;
    // }
    // if (prev == null) {
    //   return;
    // }
    // context.pushReplacement("/any", extra: prev.navReader());
    navreplaceSource(context, widget.source.getPrevious());
  }

  bool nav = false;
  Future<void> navNextChapter() async {
    if (!mounted) {
      return;
    }
    if (nav) {
      return;
    }
    if (!widget.source.hasNext()) {
      return;
    }
    nav = true;
    // Source? next = await widget.source.getNext();
    // if (!mounted) {
    //   return;
    // }
    // if (next == null) {
    //   nav = false;
    //   return;
    // }
    // context.pushReplacement("/any", extra: next.navReader());
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
            ((TextReaderSettings.textwidth.value /
                    100) *
                MediaQuery.of(context).size.width)) /
        2;
    if (TextReaderSettings.adaptivewidth.value &&
        isVertical(context)) {
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
        child: SwipeDetector(
          onDoubleTap: bookmark,
          onSwipeLeft: navNextChapter,
          onSwipeRight: navPreviousChapter,
          onLongPress: openwebview,
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
                          textreadersettings.build(() => setState(() {})),),
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
                } else if (i <= widget.source.paragraphs.length) {
                  return Padding(
                      padding: EdgeInsets.only(left: edge, right: edge),
                      child: toText(context, widget.source.paragraphs[i - 1]),);
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
              itemCount: widget.source.paragraphs.length + 2,
            ),
          ),
        ),);
  }
}
