import 'dart:math';

import 'package:awesome_extensions/awesome_extensions_flutter.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// Modified version of https://pub.dev/packages/huge_listview

class ListItem<T> {
  Object? error;
  T? item;
  int index;

  ListItem(this.index, this.item, this.error);
}

class HugeListView<T> extends StatefulWidget {
  /// An optional [ScrollablePositionedList] controller for jumping or scrolling to an item.
  final ItemScrollController? scrollController;

  /// Index of an item to initially align within the viewport.
  final int startIndex;

  /// Total number of items in the list.
  final int totalCount;

  /// Called to build items for the list with the specified [pageIndex].
  final Future<T> Function(int pageIndex) pageFuture;

  /// Called to build an individual item with the specified [index].
  final Widget Function(BuildContext context, int index, T entry) itemBuilder;

  /// Called to build a placeholder while the item is not yet availabe.
  final IndexedWidgetBuilder? placeholderBuilder;

  /// Called to build a progress widget while the whole list is initialized.
  final WidgetBuilder? waitBuilder;

  /// Called to build a widget when the list is empty.
  final WidgetBuilder? emptyBuilder;

  /// Called to build a widget when there is an error.
  final Widget Function(BuildContext context, dynamic err, Function() reload)?
  errorBuilder;

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

  /// The optional predefined LruMap to be used for cache, convenient for using LruMap outside HugeListView.
  final LruMap<int, ListItem<T>>? lruMap;

  const HugeListView({
    super.key,
    this.scrollController,
    required this.startIndex,
    required this.totalCount,
    required this.pageFuture,
    required this.itemBuilder,
    this.placeholderBuilder,
    this.waitBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.velocityThreshold = 128,
    this.firstShown,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.lruMap,
  }) : assert(totalCount > 0),
       assert(velocityThreshold >= 0);

  @override
  HugeListViewState<T> createState() => HugeListViewState<T>();
}

class HugeListViewState<T> extends State<HugeListView<T>> {
  final listener = ItemPositionsListener.create();
  late final Map<int, ListItem<T>> map;
  late final MapCache<int, ListItem<T>?> cache;
  late int totalItemCount;
  dynamic error;
  bool _frameCallbackInProgress = false;

  @override
  void initState() {
    super.initState();
    totalItemCount = widget.totalCount;
    _initCache();
    listener.itemPositions.addListener(_sendScroll);
  }

  @override
  void dispose() {
    listener.itemPositions.removeListener(_sendScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(HugeListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _sendScroll() {
    final current = _currentFirst();
    widget.firstShown?.call(current);
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
      return widget.errorBuilder!(context, error, () => _doReload(0));
    }
    if (totalItemCount == -1 && widget.waitBuilder != null) {
      return widget.waitBuilder!(context);
    }
    if (totalItemCount == 0 && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollablePositionedList.builder(
          padding: widget.padding,
          itemScrollController: widget.scrollController,
          itemPositionsListener: listener,
          scrollDirection: widget.scrollDirection,
          physics: _MaxVelocityPhysics(
            velocityThreshold: widget.velocityThreshold,
          ),
          initialScrollIndex: widget.startIndex,
          itemCount: max(totalItemCount, 0),
          itemBuilder: (context, index) {
            final pageListItem = map[index];
            if (pageListItem != null) {
              if (pageListItem.error != null) {
                return widget.errorBuilder?.call(
                      context,
                      pageListItem.error,
                      () {
                        _doReload(index);
                      },
                    ) ??
                    SizedBox(
                      height: context.height,
                      child: ErrorDisplay(
                        e: pageListItem.error,
                        actions: [
                          ErrorAction(
                            label: 'Retry',
                            onTap: () => _doReload(index),
                          ),
                        ],
                      ),
                    );
              }
              if (pageListItem.item != null) {
                return widget.itemBuilder(context, index, pageListItem.item as T);
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 10),
                child:
                    widget.placeholderBuilder?.call(context, index) ??
                    SizedBox(
                      height: context.height,
                      child: const Center(child: DionProgressBar()),
                    ),
              );
            }
            if (!Scrollable.recommendDeferredLoadingForContext(context)) {
              cache //
                  .get(index, ifAbsent: _loadPage)
                  .then(_reload)
                  .catchError(_error);
            } else if (!_frameCallbackInProgress) {
              _frameCallbackInProgress = true;
              SchedulerBinding.instance.scheduleFrameCallback(
                (d) => _deferredReload(context),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 10),
              child:
                  widget.placeholderBuilder?.call(context, index) ??
                  SizedBox(
                    height: context.height,
                    child: const Center(child: DionProgressBar()),
                  ),
            );
          },
        );
      },
    );
  }

  Future<ListItem<T>> _loadPage(int index) async {
    try {
      final item = await widget.pageFuture(index);
      return ListItem(index, item, null);
    } catch (e) {
      return ListItem(index, null, e);
    }
  }

  void _initCache() {
    map = widget.lruMap ?? LruMap<int, ListItem<T>>(maximumSize: 10);
    cache = MapCache<int, ListItem<T>>(map: map);
  }

  void onChange() {
    // TODO: Maybe readd this if we need it
    // if (listViewController.value.doReload) {
    //   _doReload(0);
    // } else if (listViewController.value.doInvalidateList) {
    //   _invalidateCache();
    //   if (listViewController.value.reloadPage) _doReload(0);
    // } else {
    //   setState(() {
    //     totalItemCount = listViewController.totalItemCount;
    //   });
    // }
  }

  void _error(dynamic e, StackTrace stackTrace) {
    if (widget.errorBuilder == null) throw e as Object;
    if (mounted) setState(() => error = e);
  }

  void _reload(ListItem<T>? value) => _doReload(value?.index ?? 0);

  void _deferredReload(BuildContext context) {
    if (!Scrollable.recommendDeferredLoadingForContext(context)) {
      _frameCallbackInProgress = false;
      _doReload(-1);
    } else {
      SchedulerBinding.instance.scheduleFrameCallback(
        (d) => _deferredReload(context),
        rescheduling: true,
      );
    }
  }

  void _doReload(int index) {
    if (mounted) setState(() {});
  }

  // void _invalidateCache() {
  //   for (final key in map.keys) {
  //     cache.invalidate(key);
  //   }
  // }
}

class _MaxVelocityPhysics extends AlwaysScrollableScrollPhysics {
  final double velocityThreshold;

  const _MaxVelocityPhysics({required this.velocityThreshold, super.parent});

  @override
  bool recommendDeferredLoading(
    double velocity,
    ScrollMetrics metrics,
    BuildContext context,
  ) {
    return velocity.abs() > velocityThreshold;
  }

  @override
  _MaxVelocityPhysics applyTo(ScrollPhysics? ancestor) {
    return _MaxVelocityPhysics(
      velocityThreshold: velocityThreshold,
      parent: buildParent(ancestor),
    );
  }
}
