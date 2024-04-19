import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:huge_listview/src/draggable_scrollbar.dart';
import 'package:huge_listview/src/draggable_scrollbar_thumbs.dart';
import 'package:huge_listview/src/huge_listview_controller.dart';
import 'package:huge_listview/src/page_result.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

typedef HugeListViewPageFuture<T> = Future<List<T>> Function(int pageIndex);
typedef HugeListViewItemBuilder<T> = Widget Function(
    BuildContext context, int index, T entry);
typedef HugeListViewErrorBuilder = Widget Function(
    BuildContext context, dynamic error);

class HugeListView<T> extends StatefulWidget {
  /// An optional [ScrollablePositionedList] controller for jumping or scrolling to an item.
  @Deprecated('Use `scrollController` instead.')
  final ItemScrollController? controller;

  /// An optional [ScrollablePositionedList] controller for jumping or scrolling to an item.
  final ItemScrollController? scrollController;

  /// An optional [HugeListViewController] controller to control the behavior of the list.
  final HugeListViewController? listViewController;

  /// Size of the page. [HugeListView] only keeps a few pages of items in memory any time.
  final int pageSize;

  /// Index of an item to initially align within the viewport.
  final int startIndex;

  /// Total number of items in the list.
  @Deprecated('Use `totalItemCount` of the `listViewController` instead.')
  final int? totalCount;

  /// Called to build items for the list with the specified [pageIndex].
  final HugeListViewPageFuture<T> pageFuture;

  /// Called to build the thumb. One of [DraggableScrollbarThumbs.RoundedRectThumb], [DraggableScrollbarThumbs.ArrowThumb]
  /// or [DraggableScrollbarThumbs.SemicircleThumb], or build your own.
  final ScrollThumbBuilder thumbBuilder;

  /// Background color of scroll thumb, defaults to white.
  final Color thumbBackgroundColor;

  /// Drawing color of scroll thumb, defaults to gray.
  final Color thumbDrawColor;

  /// Height of scroll thumb, defaults to 48.
  final double thumbHeight;

  /// Called to build an individual item with the specified [index].
  final HugeListViewItemBuilder<T> itemBuilder;

  /// Called to build a placeholder while the item is not yet availabe.
  final IndexedWidgetBuilder placeholderBuilder;

  /// Called to build a progress widget while the whole list is initialized.
  final WidgetBuilder? waitBuilder;

  /// Called to build a widget when the list is empty.
  @Deprecated('Use `emptyBuilder` instead.')
  final WidgetBuilder? emptyResultBuilder;

  /// Called to build a widget when the list is empty.
  final WidgetBuilder? emptyBuilder;

  /// Called to build a widget when there is an error.
  final HugeListViewErrorBuilder? errorBuilder;

  /// The velocity above which the individual items stop being drawn until the scrolling rate drops.
  final double velocityThreshold;

  /// Event to call with the index of the topmost visible item in the viewport while scrolling.
  /// Can be used to display the current letter of an alphabetically sorted list, for instance.
  final ValueChanged<int>? firstShown;

  /// The axis along which the list view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// The amount of space by which to inset the list.
  final EdgeInsets? padding;

  /// Whether the scroll thumb slides out when not used, defaults to always visible.
  final bool alwaysVisibleThumb;

  /// How quickly the scroll thumb animates in and out. Ignored if `alwaysVisibleThumb` is true.
  final Duration thumbAnimationDuration;

  /// How long the scroll thumb stays visible before disappearing. Ignored if `alwaysVisibleThumb` is true.
  final Duration thumbVisibleDuration;

  /// The optional predefined LruMap to be used for cache, convenient for using LruMap outside HugeListView.
  final LruMap<int, HugeListViewPageResult<T>>? lruMap;

  final ScrollOffsetController? scrollOffsetController;

  const HugeListView({
    super.key,
    @Deprecated('Use `scrollController` instead.') this.controller,
    this.scrollController,
    this.listViewController,
    required this.pageSize,
    required this.startIndex,
    @Deprecated('Use `totalItemCount` of the `listViewController` instead.')
    this.totalCount,
    required this.pageFuture,
    required this.thumbBuilder,
    required this.itemBuilder,
    required this.placeholderBuilder,
    this.waitBuilder,
    @Deprecated('Use `emptyBuilder` instead.') this.emptyResultBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.velocityThreshold = 128,
    this.firstShown,
    this.scrollDirection = Axis.vertical,
    this.thumbBackgroundColor = Colors.white,
    this.thumbDrawColor = Colors.grey,
    this.thumbHeight = 48.0,
    this.alwaysVisibleThumb = true,
    this.thumbAnimationDuration = kThemeAnimationDuration,
    this.thumbVisibleDuration = const Duration(milliseconds: 1000),
    this.padding,
    this.lruMap,
    this.scrollOffsetController,
  })  : assert(pageSize > 0),
        assert(velocityThreshold >= 0);

  @override
  HugeListViewState<T> createState() => HugeListViewState<T>();
}

class HugeListViewState<T> extends State<HugeListView<T>> {
  final scrollKey = GlobalKey<DraggableScrollbarState>();
  final listener = ItemPositionsListener.create();
  late HugeListViewController listViewController;
  late final Map<int, HugeListViewPageResult<T>> map;
  late final MapCache<int, HugeListViewPageResult<T>?> cache;
  late int totalItemCount;
  dynamic error;
  bool _frameCallbackInProgress = false;

  @override
  void initState() {
    super.initState();

    listViewController = widget.listViewController ??
        HugeListViewController(
            totalItemCount: widget.totalCount ??
                -1 >>> 1); // =int.MAX, temporarily until `totalCount` removed
    listViewController.addListener(onChange);
    totalItemCount = listViewController.totalItemCount;

    _initCache();
    listener.itemPositions.addListener(_sendScroll);
  }

  @override
  void dispose() {
    listViewController.removeListener(onChange);
    if (widget.listViewController == null) listViewController.dispose();
    listener.itemPositions.removeListener(_sendScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(HugeListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.listViewController == null &&
        oldWidget.listViewController != null) {
      listViewController =
          HugeListViewController.fromValue(oldWidget.listViewController!.value);
    } else if (widget.listViewController != null &&
        oldWidget.listViewController == null) {
      listViewController.dispose();
    }
  }

  void _sendScroll() {
    int current = _currentFirst();
    widget.firstShown?.call(current);
    scrollKey.currentState?.setPosition(current / totalItemCount, current);
  }

  int _currentFirst() {
    try {
      return listener.itemPositions.value.first.index;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    if (totalItemCount == -1 && widget.waitBuilder != null) {
      return widget.waitBuilder!(context);
    }
    if (totalItemCount == 0 && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    if (totalItemCount == 0 && widget.emptyResultBuilder != null) {
      return widget.emptyResultBuilder!(context);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollablePositionedList.builder(
          scrollOffsetController: widget.scrollOffsetController,
          padding: widget.padding,
          itemScrollController: widget.scrollController ?? widget.controller,
          itemPositionsListener: listener,
          scrollDirection: widget.scrollDirection,
          physics:
              _MaxVelocityPhysics(velocityThreshold: widget.velocityThreshold),
          initialScrollIndex: widget.startIndex,
          itemCount: max(totalItemCount, 0),
          itemBuilder: (context, index) {
            final page = index ~/ widget.pageSize;
            final pageResult = map[page];
            final valueIndex = index % widget.pageSize;
            if (pageResult != null && pageResult.items.length > valueIndex) {
              final value = pageResult.items.elementAt(valueIndex);
              if (value != null) {
                return widget.itemBuilder(context, index, value);
              }
            }

            if (!Scrollable.recommendDeferredLoadingForContext(context)) {
              cache //
                  .get(page, ifAbsent: _loadPage)
                  .then(_reload)
                  .catchError(_error);
            } else if (!_frameCallbackInProgress) {
              _frameCallbackInProgress = true;
              SchedulerBinding.instance
                  .scheduleFrameCallback((d) => _deferredReload(context));
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 10),
              child: widget.placeholderBuilder(context, index),
            );
          },
        );
      },
    );
  }

  Future<HugeListViewPageResult<T>> _loadPage(int index) async {
    return HugeListViewPageResult(index, await widget.pageFuture(index));
  }

  void _initCache() {
    map = widget.lruMap ??
        LruMap<int, HugeListViewPageResult<T>>(
            maximumSize: 256 ~/ widget.pageSize);
    cache = MapCache<int, HugeListViewPageResult<T>>(map: map);
  }

  void onChange() {
    if (listViewController.value.doReload) {
      _doReload(0);
    } else if (listViewController.value.doInvalidateList) {
      _invalidateCache();
      if (listViewController.value.reloadPage) _doReload(0);
    } else {
      setState(() {
        totalItemCount = listViewController.totalItemCount;
      });
    }
  }

  void _error(dynamic e, StackTrace stackTrace) {
    if (widget.errorBuilder == null) throw e;
    if (mounted) setState(() => error = e);
  }

  void _reload(HugeListViewPageResult<T>? value) =>
      _doReload(value?.index ?? 0);

  void _deferredReload(BuildContext context) {
    if (!Scrollable.recommendDeferredLoadingForContext(context)) {
      _frameCallbackInProgress = false;
      _doReload(-1);
    } else {
      SchedulerBinding.instance.scheduleFrameCallback(
          (d) => _deferredReload(context),
          rescheduling: true);
    }
  }

  void _doReload(int index) {
    if (mounted) setState(() {});
  }

  /// Jump to the [position] in the list. [position] is between 0.0 (first item) and 1.0 (last item), practically currentIndex / totalCount.
  /// To jump to a specific item, use [ItemScrollController.jumpTo] or [ItemScrollController.scrollTo].
  void setPosition(double position) {
    scrollKey.currentState?.setPosition(position, _currentFirst());
  }

  void _invalidateCache() {
    for (final key in map.keys) {
      cache.invalidate(key);
    }
  }
}

class _MaxVelocityPhysics extends AlwaysScrollableScrollPhysics {
  final double velocityThreshold;

  const _MaxVelocityPhysics(
      {required this.velocityThreshold, super.parent});

  @override
  bool recommendDeferredLoading(
      double velocity, ScrollMetrics metrics, BuildContext context) {
    return velocity.abs() > velocityThreshold;
  }

  @override
  _MaxVelocityPhysics applyTo(ScrollPhysics? ancestor) {
    return _MaxVelocityPhysics(
        velocityThreshold: velocityThreshold, parent: buildParent(ancestor));
  }
}
