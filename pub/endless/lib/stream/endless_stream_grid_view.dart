import 'dart:async';

import 'package:endless/endless_state_property.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:endless/stream/endless_stream_grid_view_data.dart';
import 'package:endless/stream/endless_stream_scroll_view.dart';
import 'package:endless/stream/endless_stream_scroll_view_data.dart';
import 'package:flutter/material.dart';

/// An infinite loading grid view that builds items added to the stream into a scrollable grid.
class EndlessStreamGridView<T> extends StatelessWidget {
  /// A function which adds more items to the stream when the grid view is scrolled
  /// to its threshold for loading more items determined by the [extentAfterFactor].
  final void Function() loadMore;

  /// The stream of items that will be added to the grid view.
  final Stream<List<T>> stream;

  /// The builder function for the grid view items.
  final Function(
    BuildContext context, {
    required T item,
    required int index,
    required int totalItems,
  }) itemBuilder;

  /// The stream controller used to perform actions on the grid view such as loading more data
  /// or clearing the grid.
  final EndlessStreamController<T>? controller;

  /// The scroll controller for the grid view.
  final ScrollController? scrollController;

  /// Whether to immediately request data from the stream when it is first subscribed to by calling
  /// the [EndlessStreamGridView.loadMore] API.
  final bool? loadOnSubscribe;

  /// Controls the layout of tiles in a grid. See [GridView.gridDelegate]
  final SliverGridDelegate gridDelegate;

  /// The padding around the scroll view.
  final EdgeInsets? padding;

  /// The builder function for the grid view header.
  final Widget Function(BuildContext context)? headerBuilder;

  /// The state property for the grid view header.
  final EndlessStateProperty? headerBuilderState;

  /// The builder function for the grid view empty state.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// The state property for the grid view empty state.
  final EndlessStateProperty? emptyBuilderState;

  /// The builder function for the grid view load more action widget.
  final Widget Function(BuildContext context)? loadMoreBuilder;

  /// The state property for the grid view load more action widget.
  final EndlessStateProperty? loadMoreBuilderState;

  /// The builder function for the grid view footer.
  final Widget Function(BuildContext context)? footerBuilder;

  /// The state property for the grid view footer.
  final EndlessStateProperty? footerBuilderState;

  /// The builder function for the grid view loading state.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// The state property for the grid view loading state.
  final EndlessStateProperty? loadingBuilderState;

  /// The fraction of the remaining quantity of content conceptually "below" the viewport in the scrollable
  /// relative to the maximum height of the scrollable region at which point [loadMore] should be called to
  /// load more data.
  final double? extentAfterFactor;

  /// A callback function that provides the current states of the endless scroll view whenever they change.
  final void Function(Set<EndlessState> states)? onStateChange;

  // The physics for the grid view.
  final ScrollPhysics? physics;

  const EndlessStreamGridView({
    required this.loadMore,
    required this.itemBuilder,
    required this.gridDelegate,
    required this.stream,
    this.headerBuilder,
    this.headerBuilderState,
    this.emptyBuilder,
    this.emptyBuilderState,
    this.loadingBuilder,
    this.loadingBuilderState,
    this.loadMoreBuilder,
    this.loadMoreBuilderState,
    this.footerBuilder,
    this.footerBuilderState,
    this.controller,
    this.scrollController,
    this.onStateChange,
    this.physics,
    this.extentAfterFactor = 0.4,
    this.loadOnSubscribe = true,
    this.padding = const EdgeInsets.all(0),
    key,
  }) : super(key: key);

  static EndlessStreamGridView fromData<Y>(EndlessStreamGridViewData<Y> data) {
    return EndlessStreamGridView<Y>(
      gridDelegate: data.gridDelegate,
      extentAfterFactor: data.extentAfterFactor,
      loadMore: data.loadMore,
      itemBuilder: data.itemBuilder,
      stream: data.stream,
      headerBuilder: data.headerBuilder,
      headerBuilderState: data.headerBuilderState,
      emptyBuilder: data.emptyBuilder,
      emptyBuilderState: data.emptyBuilderState,
      loadingBuilder: data.loadingBuilder,
      loadingBuilderState: data.loadingBuilderState,
      loadMoreBuilder: data.loadMoreBuilder,
      loadMoreBuilderState: data.loadMoreBuilderState,
      footerBuilder: data.footerBuilder,
      footerBuilderState: data.footerBuilderState,
      controller: data.controller,
      scrollController: data.scrollController,
      padding: data.padding,
      loadOnSubscribe: data.loadOnSubscribe,
      physics: data.physics,
    );
  }

  @override
  Widget build(context) {
    return EndlessStreamScrollView<T>(
      scrollViewBuilder: (items) {
        return SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return itemBuilder(
                context,
                item: items[index],
                index: index,
                totalItems: items.length,
              );
            },
            childCount: items.length,
          ),
        );
      },
      loadMoreScrollViewData: EndlessStreamScrollViewData<T>(
        extentAfterFactor: extentAfterFactor,
        headerBuilder: headerBuilder,
        emptyBuilder: emptyBuilder,
        loadingBuilder: loadingBuilder,
        loadMoreBuilder: loadMoreBuilder,
        footerBuilder: footerBuilder,
        headerBuilderState: headerBuilderState,
        emptyBuilderState: emptyBuilderState,
        loadingBuilderState: loadingBuilderState,
        loadMoreBuilderState: loadMoreBuilderState,
        footerBuilderState: footerBuilderState,
        loadMore: loadMore,
        controller: controller,
        scrollController: scrollController,
        stream: stream,
        loadOnSubscribe: loadOnSubscribe,
        padding: padding,
        onStateChange: onStateChange,
        physics: physics,
      ),
    );
  }
}
