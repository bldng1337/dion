import 'package:endless/endless_state_property.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:endless/stream/endless_stream_scroll_view_data.dart';
import 'package:flutter/material.dart';

class EndlessStreamListViewData<T> extends EndlessStreamScrollViewData<T> {
  final Widget Function(
    BuildContext context, {
    required T item,
    required int index,
    required int totalItems,
  }) itemBuilder;
  final double? itemPadding;

  EndlessStreamListViewData({
    required this.itemBuilder,
    required this.itemPadding,
    required double? extentAfterFactor,
    required Widget Function(BuildContext context)? headerBuilder,
    required Widget Function(BuildContext context)? emptyBuilder,
    required Widget Function(BuildContext context)? loadingBuilder,
    required Widget Function(BuildContext context)? loadMoreBuilder,
    required Widget Function(BuildContext context)? footerBuilder,
    required EndlessStateProperty? headerBuilderState,
    required EndlessStateProperty? emptyBuilderState,
    required EndlessStateProperty? loadingBuilderState,
    required EndlessStateProperty? loadMoreBuilderState,
    required EndlessStateProperty? footerBuilderState,
    required void Function() loadMore,
    required Stream<List<T>> stream,
    required EndlessStreamController<T>? controller,
    required ScrollController? scrollController,
    required EdgeInsets? padding,
    required bool? loadOnSubscribe,
    required ScrollPhysics? physics,
    required final void Function(Set<EndlessState> states)? onStateChange,
  }) : super(
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
          stream: stream,
          controller: controller,
          scrollController: scrollController,
          padding: padding,
          loadOnSubscribe: loadOnSubscribe,
          onStateChange: onStateChange,
          physics: physics,
        );
}
