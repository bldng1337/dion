import 'package:endless/endless_state_property.dart';
import 'package:endless/stream/endless_stream_builder.dart';
import 'package:endless/stream/endless_stream_scroll_view_data.dart';
import 'package:endless/utils/sliver_detector.dart';
import 'package:endless/widgets/endless_default_loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

/// Infinite loading scroll view using a CustomScrollView with the following customizable builders:
/// - header builder
/// - items builder
/// - empty state builder
/// - loading builder
/// - load more builder
/// - footer builder
/// Implements a StateProperty builder pattern for customizing the different builders based on the current
/// states of the infinite loading scroll view.
class EndlessStreamScrollView<T> extends StatefulWidget {
  final EndlessStreamScrollViewData<T> loadMoreScrollViewData;
  final Widget Function(List<T> items) scrollViewBuilder;

  const EndlessStreamScrollView({
    required this.scrollViewBuilder,
    required this.loadMoreScrollViewData,
    key,
  }) : super(key: key);

  @override
  _EndlessStreamScrollViewState<T> createState() =>
      _EndlessStreamScrollViewState();
}

class _EndlessStreamScrollViewState<T>
    extends State<EndlessStreamScrollView<T>> {
  late ScrollController _scrollController;

  @override
  initState() {
    super.initState();

    _scrollController =
        widget.loadMoreScrollViewData.scrollController ?? ScrollController();
  }

  @override
  dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildDefaultLoader(BuildContext context) {
    return const EndlessDefaultLoadingIndicator();
  }

  Widget? _buildSliverBoxAdapter(Widget? child) {
    if (child != null) {
      if (isSliver(child)) {
        return child;
      }
      return SliverToBoxAdapter(
        child: child,
      );
    }

    return null;
  }

  /// Builds the sliver sections for the custom scroll view using either their
  /// specified builder functions or state properties.
  List<Widget> _buildSlivers(Set<EndlessState> states, List<T> items) {
    final loadMoreScrollViewData = widget.loadMoreScrollViewData;
    final padding = loadMoreScrollViewData.padding;

    final headerBuilderState = loadMoreScrollViewData.headerBuilderState ??
        resolveHeaderBuilderToStateProperty(
          loadMoreScrollViewData.headerBuilder,
        );
    final emptyBuilderState = loadMoreScrollViewData.emptyBuilderState ??
        resolveEmptyBuilderToStateProperty(loadMoreScrollViewData.emptyBuilder);
    final loadingBuilderState = loadMoreScrollViewData.loadingBuilderState ??
        resolveLoadingBuilderToStateProperty(
          // A default loader is bundled with the scroll view
          loadMoreScrollViewData.loadingBuilder ?? _buildDefaultLoader,
        );
    final loadMoreBuilderState = loadMoreScrollViewData.loadMoreBuilderState ??
        resolveLoadMoreBuilderToStateProperty(
          loadMoreScrollViewData.loadMoreBuilder,
        );
    final footerBuilderState = loadMoreScrollViewData.footerBuilderState ??
        resolveFooterBuilderToStateProperty(
          loadMoreScrollViewData.footerBuilder,
        );

    final slivers = [
      _buildSliverBoxAdapter(headerBuilderState.resolve(context, states)),
      states.contains(EndlessState.empty)
          ? _buildSliverBoxAdapter(
              emptyBuilderState.resolve(context, states),
            )
          : widget.scrollViewBuilder(items),
      _buildSliverBoxAdapter(
        loadingBuilderState.resolve(context, states),
      ),
      _buildSliverBoxAdapter(
        loadMoreBuilderState.resolve(
          context,
          states,
        ),
      ),
      _buildSliverBoxAdapter(
        footerBuilderState.resolve(context, states),
      ),
    ].where((sliver) => sliver != null).toList();

    // The top sliver is wrapped in the top padding and the bottom sliver is wrapped in the bottom padding.
    if (slivers.length >= 2) {
      slivers[0] = SliverPadding(
        padding: EdgeInsets.only(top: padding?.top ?? 0),
        sliver: slivers[0],
      );

      slivers[slivers.length - 1] = SliverPadding(
        padding: EdgeInsets.only(bottom: padding?.bottom ?? 0),
        sliver: slivers[slivers.length - 1],
      );
    } else if (slivers.length == 1) {
      slivers[0] = SliverPadding(
        padding: EdgeInsets.only(
          top: padding?.top ?? 0,
          bottom: padding?.bottom ?? 0,
        ),
        sliver: slivers[0],
      );
    }

    return List<Widget>.from(slivers);
  }

  @override
  Widget build(context) {
    final loadMoreScrollViewData = widget.loadMoreScrollViewData;
    final padding = loadMoreScrollViewData.padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return EndlessStreamBuilder<T>(
          loadMore: loadMoreScrollViewData.loadMore,
          stream: loadMoreScrollViewData.stream,
          controller: loadMoreScrollViewData.controller,
          onStateChange: loadMoreScrollViewData.onStateChange,
          loadOnSubscribe: loadMoreScrollViewData.loadOnSubscribe!,
          builder: ({
            required states,
            required items,
            required loadMore,
          }) {
            final isLoading = states.contains(EndlessState.loading);
            final isEmpty = states.contains(EndlessState.empty);
            final canLoadMore = !states.contains(EndlessState.done);

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final scrollPosition = _scrollController.position;

                  if (!isLoading &&
                      canLoadMore &&
                      !isEmpty &&
                      scrollPosition.userScrollDirection ==
                          ScrollDirection.reverse &&
                      scrollPosition.extentAfter <
                          constraints.maxHeight *
                              loadMoreScrollViewData.extentAfterFactor!) {
                    loadMore();
                  }
                }

                return false;
              },
              child: Padding(
                // The horizontal padding is applied around the scroll view
                padding: EdgeInsets.only(
                  left: padding?.left ?? 0,
                  right: padding?.right ?? 0,
                ),
                child: CustomScrollView(
                  controller: _scrollController,
                  shrinkWrap: true,
                  physics: loadMoreScrollViewData.physics,
                  slivers: _buildSlivers(states, items),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
