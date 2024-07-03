import 'dart:async';

import 'package:endless/endless_state_property.dart';
import 'package:endless/pagination/endless_pagination_controller.dart';
import 'package:endless/pagination/endless_pagination_delegate.dart';
import 'package:endless/pagination/endless_pagination_stream_builder.dart';
import 'package:endless/stream/endless_stream_list_view.dart';
import 'package:endless/stream/endless_stream_list_view_data.dart';
import 'package:flutter/material.dart';

/// An infinite loading list view that builds items loaded from the [loadMore] API into a scrollable list.
class EndlessPaginationListView<T> extends StatelessWidget {
  /// A function which returns the additional items to add to the list view when it is scrolled
  /// to its threshold for loading more items determined by the [extentAfterFactor].
  final Future<List<T>> Function(int pageIndex) loadMore;

  /// The builder function for the list view items.
  final Widget Function(
    BuildContext context, {
    required T item,
    required int index,
    required int totalItems,
  }) itemBuilder;

  /// The stream controller used to perform actions on the list view such as loading more data
  /// or clearing the list.
  final EndlessPaginationController<T>? controller;

  /// The scroll controller for the list view.
  final ScrollController? scrollController;

  /// Whether to immediately request data from the stream when it is first subscribed to by calling
  /// the [loadMore] API.
  final bool? initialLoad;

  /// The padding around the scroll view.
  final EdgeInsets? padding;

  /// The padding number in between each item in the list view.
  final double? itemPadding;

  /// The delegate that specifies the pagination requirements for the list view such as the maximum
  /// number of pages to load and the page size.
  final EndlessPaginationDelegate paginationDelegate;

  /// The fraction of the remaining quantity of content conceptually "below" the viewport in the scrollable
  /// relative to the maximum height of the scrollable region at which point [loadMore] should be called to
  /// load more data.
  final double? extentAfterFactor;

  /// The builder function for the list view header.
  final Widget Function(BuildContext context)? headerBuilder;

  /// The state property for the list view header.
  final EndlessStateProperty? headerBuilderState;

  /// The builder function for the list view empty state.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// The state property for the list view empty state.
  final EndlessStateProperty? emptyBuilderState;

  /// The builder function for the list view load more action widget.
  final Widget Function(BuildContext context)? loadMoreBuilder;

  /// The state property for the list view load more action widget.
  final EndlessStateProperty? loadMoreBuilderState;

  /// The builder function for the list view footer.
  final Widget Function(BuildContext context)? footerBuilder;

  /// The state property for the list view footer.
  final EndlessStateProperty? footerBuilderState;

  /// The builder function for the list view loading state.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// The state property for the list view loading state.
  final EndlessStateProperty? loadingBuilderState;

  /// A callback function that provides the current states of the endless scroll view whenever they change.
  final void Function(Set<EndlessState> states)? onStateChange;

  final ScrollPhysics? physics;

  const EndlessPaginationListView({
    required this.loadMore,
    required this.itemBuilder,
    required this.paginationDelegate,
    this.extentAfterFactor = 0.4,
    this.controller,
    this.scrollController,
    this.onStateChange,
    this.padding,
    this.itemPadding,
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
    this.physics,
    this.initialLoad = true,
    key,
  }) : super(key: key);

  @override
  Widget build(context) {
    return EndlessPaginationStreamBuilder.fromData<T>(
      EndlessPaginationData(
        loadMore: loadMore,
        paginationDelegate: paginationDelegate,
        initialLoad: initialLoad,
        controller: controller,
        builder: ({
          required loadMore,
          required controller,
          required loadOnSubscribe,
          required stream,
        }) {
          // We use this pattern to ensure that all fields from the list view public API
          // are passed through from the paginated list view to the stream list view. Otherwise,
          // a non-required public API could be omitted here and we wouldn't realize it.
          return EndlessStreamListView.fromData<T>(
            EndlessStreamListViewData<T>(
              extentAfterFactor: extentAfterFactor,
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
              itemPadding: itemPadding,
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
