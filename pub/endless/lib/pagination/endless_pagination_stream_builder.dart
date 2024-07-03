import 'dart:async';
import 'package:endless/pagination/endless_pagination_controller.dart';
import 'package:endless/pagination/endless_pagination_delegate.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:flutter/material.dart';

class EndlessPaginationData<T> {
  final Future<List<T>> Function(int pageIndex) loadMore;
  final Widget Function({
    required Stream<List<T>> stream,
    required void Function() loadMore,
    required EndlessStreamController<T> controller,
    required bool loadOnSubscribe,
  }) builder;
  final EndlessPaginationController<T>? controller;
  final bool? initialLoad;
  final EndlessPaginationDelegate paginationDelegate;

  EndlessPaginationData({
    required this.loadMore,
    required this.builder,
    required this.controller,
    required this.paginationDelegate,
    required this.initialLoad,
  });
}

// Adapter for an EndlessPagination to an EndlessStream so that it
// can then reuse the scroll view builder logic of the EndlessStream
class EndlessPaginationStreamBuilder<T> extends StatefulWidget {
  final Future<List<T>> Function(int pageIndex) loadMore;
  final Widget Function({
    required Stream<List<T>> stream,
    required void Function() loadMore,
    required EndlessStreamController<T> controller,
    required bool loadOnSubscribe,
  }) builder;
  final EndlessPaginationController<T>? controller;

  /// Whether the paginated scroll view should load data once on initial startup
  final bool? initialLoad;

  final EndlessPaginationDelegate paginationDelegate;

  const EndlessPaginationStreamBuilder({
    required this.loadMore,
    required this.builder,
    required this.paginationDelegate,
    this.controller,
    this.initialLoad = true,
    key,
  }) : super(key: key);

  @override
  _EndlessPaginationStreamBuilderState<T> createState() =>
      _EndlessPaginationStreamBuilderState<T>();

  static EndlessPaginationStreamBuilder fromData<Y>(
    EndlessPaginationData<Y> data,
  ) {
    return EndlessPaginationStreamBuilder<Y>(
      loadMore: data.loadMore,
      controller: data.controller,
      builder: data.builder,
      paginationDelegate: data.paginationDelegate,
      initialLoad: data.initialLoad ?? true,
    );
  }
}

class _EndlessPaginationStreamBuilderState<T>
    extends State<EndlessPaginationStreamBuilder<T>> {
  int _pageIndex = 0;
  StreamSubscription? _pageStreamSubscription;
  StreamController<List<T>> _streamController = StreamController();
  final EndlessStreamController<T> _streamLoadMoreController =
      EndlessStreamController();
  late bool _loadOnSubscribe;

  @override
  initState() {
    super.initState();

    _loadOnSubscribe = widget.initialLoad ?? false;

    final controller = widget.controller;

    if (controller != null) {
      controller.isMounted = () {
        return mounted;
      };
      controller.loadMore = () {
        _streamLoadMoreController.loadMore();
      };
      controller.reload = _reload;
      controller.clear = _clear;
      controller.remove = (T item) {
        _streamLoadMoreController.remove(item);
      };
    }
  }

  @override
  dispose() {
    super.dispose();
    _cancelPageSubscription();
  }

  _cancelPageSubscription() async {
    if (_pageStreamSubscription != null) {
      await _pageStreamSubscription!.cancel();
      _pageStreamSubscription = null;
    }
  }

  _loadMore() async {
    _cancelPageSubscription();

    // A stream is used for loading the page of data so that if the list view is reset
    // while still loading data, it can just cancel the first stream and discard the result.
    _pageStreamSubscription = Stream.fromFuture(
      widget.loadMore(_pageIndex),
    ).listen(
      (newItems) {
        final maxPages = widget.paginationDelegate.maxPages;
        final canLoadMore =
            newItems.length >= widget.paginationDelegate.pageSize &&
                (maxPages == null || _pageIndex < maxPages - 1);

        _streamController.sink.add(newItems);

        if (canLoadMore) {
          _pageIndex = _pageIndex + 1;
        } else {
          _streamController.close();
        }
      },
    )..onDone(() {
        _cancelPageSubscription();
      });
  }

  _reload() {
    _cancelPageSubscription();
    _streamLoadMoreController.clear(lazy: true);

    setState(() {
      _pageIndex = 0;
      _loadOnSubscribe = true;
      _streamController = StreamController();
    });
  }

  _clear() {
    _cancelPageSubscription();
    _streamLoadMoreController.clear();

    setState(() {
      _pageIndex = 0;
      _loadOnSubscribe = false;
      _streamController = StreamController();
    });
  }

  @override
  Widget build(context) {
    return widget.builder(
      stream: _streamController.stream,
      loadMore: _loadMore,
      controller: _streamLoadMoreController,
      loadOnSubscribe: _loadOnSubscribe,
    );
  }
}
