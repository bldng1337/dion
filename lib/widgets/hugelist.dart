import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class Hugelist<T> extends StatefulWidget {
  final Widget Function(BuildContext context, int major, int minor, T thing)
      builder;
  final ScrollOffsetController? scrollOffsetController;
  final FutureOr<T> Function(int major) load;
  final int Function(T thing) size;
  final LruMap<int,T>? map;
  final Function(int major, int progress)? onscroll;
  final int startMajor;
  final int startMinor; //TODO: Implment
  const Hugelist(
      {super.key,
      required this.builder,
      required this.load,
      this.startMajor = 0,
      this.startMinor = 0,
      this.onscroll,
      this.scrollOffsetController,
      this.map, required this.size});

  @override
  _HugelistState createState() => _HugelistState();
}

class _HugelistState<T> extends State<Hugelist<T>> {
  late final MapCache<int, T> cache;
  late final Map<int, T> map;

  ItemScrollController sci = ItemScrollController();
  late ScrollOffsetController sc;
  ItemPositionsListener ipl = ItemPositionsListener.create();
  ScrollOffsetListener sol = ScrollOffsetListener.create();

  @override
  void initState() {
    super.initState();
    sc = widget.scrollOffsetController ?? ScrollOffsetController();
    map = widget.map??LruMap(maximumSize: 4);
    cache = MapCache(map: map);
    //TODO: make minor progress work
    sol.changes.listen((event) {
      int min = ipl.itemPositions.value
          .where((ItemPosition position) => position.itemTrailingEdge > 0)
          .reduce((ItemPosition min, ItemPosition position) =>
              position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
          .index;
      ItemPosition minpos =
          ipl.itemPositions.value.firstWhere((element) => element.index == min);
      double percent = minpos.itemLeadingEdge.abs() /
          (minpos.itemLeadingEdge.abs() + minpos.itemTrailingEdge.abs());
      if (widget.onscroll != null) {
        widget.onscroll!(min, (percent * 100).floor());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const total = -1 >>> 1;
    return ScrollablePositionedList.builder(
      itemScrollController: sci,
      scrollOffsetController: sc,
      itemPositionsListener: ipl,
      scrollOffsetListener: sol,
      itemCount: total,
      initialAlignment: 0.5,
      initialScrollIndex: widget.startMajor,
      itemBuilder: (BuildContext context, int major) {
        return FutureBuilder(
            future: cache.get(major, ifAbsent: widget.load),
            builder: (BuildContext context, AsyncSnapshot<T?> snap) {
              switch (snap.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                case ConnectionState.active:
                  return SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: (const Center(
                      child: CircularProgressIndicator(),
                    )),
                  );
                case ConnectionState.done:
                  if (!snap.hasData||snap.data==null) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: (const Center(
                        child: Text("Error"),
                      )),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(widget.size(snap.data!), (minor) => widget.builder(context, major, minor, snap.data!)),
                  );
              }
            });
      },
    );
  }
}
