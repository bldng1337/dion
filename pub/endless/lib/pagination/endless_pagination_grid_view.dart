import 'dart:async';

import 'package:endless/endless_state_property.dart';
import 'package:endless/pagination/endless_pagination_controller.dart';
import 'package:endless/pagination/endless_pagination_delegate.dart';
import 'package:endless/pagination/endless_pagination_stream_builder.dart';
import 'package:endless/stream/endless_stream_grid_view.dart';
import 'package:endless/stream/endless_stream_grid_view_data.dart';
import 'package:flutter/material.dart';

/// An infinite loading grid view that builds items loaded from the [loadMore] API into a scrollable grid.
class EndlessPaginationGridView<T> extends StatelessWidget {
  /// A function which returns the additional items to add to the grid view when it is scrolled
  /// to its threshold for loading more items determined by the [extentAfterFactor].
  final Future<List<T>> Function(int pageIndex) loadMore;

  /// The builder function for the grid view items.
  final Widget Function(
    BuildContext context, {
    required T item,
    required int index,
    required int totalItems,
  }) itemBuilder;

  /// The stream controller used to perform actions on the grid view such as loading more data
  /// or clearing the grid.
  final EndlessPaginationController<T>? controller;

  /// Whether to immediately request data from the stream when it is first subscribed to by calling
  /// the [loadMore] API.
  final bool? initialLoad;

  /// The padding around the scroll view.
  final EdgeInsets? padding;

  /// Controls the layout of tiles in a grid. See [GridView.gridDelegate].
  final SliverGridDelegate gridDelegate;

  /// The delegate that specifies the pagination requirements for the grid view such as the maximum
  /// number of pages to load and the page size.
  final EndlessPaginationDelegate paginationDelegate;

  /// The fraction of the remaining quantity of content conceptually "below" the viewport in the scrollable
  /// relative to the maximum height of the scrollable region at which point [loadMore] should be called to
  /// load more data.
  final double? extentAfterFactor;

  /// The scroll controller for the grid view.
  final ScrollController? scrollController;

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

  /// A callback function that provides the current states of the endless scroll view whenever they change.
  final void Function(Set<EndlessState> states)? onStateChange;

  // The scroll physics for the grid view.
  final ScrollPhysics? physics;

  const EndlessPaginationGridView({
    required this.loadMore,
    required this.itemBuilder,
    required this.paginationDelegate,
    required this.gridDelegate,
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
    this.padding,
    this.onStateChange,
    this.physics,
    this.initialLoad = true,
    this.extentAfterFactor = 0.4,
    key,
  }) : super(key: key);

  @override
  Widget build(context) {
    return EndlessPaginationStreamBuilder.fromData<T>(
      EndlessPaginationData(
        loadMore: loadMore,
        initialLoad: initialLoad,
        paginationDelegate: paginationDelegate,
        controller: controller,
        builder: ({
          required loadMore,
          required controller,
          required loadOnSubscribe,
          required stream,
        }) {
          return EndlessStreamGridView.fromData<T>(
            EndlessStreamGridViewData<T>(
              extentAfterFactor: extentAfterFactor,
              gridDelegate: gridDelegate,
              itemBuilder: itemBuilder,
              loadMore: loadMore,
              controller: controller,
              scrollController: scrollController,
              stream: stream,
              headerBuilder: headerBuilder,
              headerBuilderState: headerBuilderState,
              emptyBuilder: emptyBuilder,
              emptyBuilderState: emptyBuilderState,
              loadingBuilder: loadingBuilder,
              loadingBuilderState: loadingBuilderState,
              loadMoreBuilder: loadMoreBuilder,
              loadMoreBuilderState: loadMoreBuilderState,
              footerBuilder: footerBuilder,
              footerBuilderState: footerBuilderState,
              padding: padding,
              loadOnSubscribe: loadOnSubscribe,
              onStateChange: onStateChange,
              physics: physics,
            ),
          );
        },
      ),
    );
  }
}
