import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:inline_result/inline_result.dart';

abstract class DataSource<T> {
  String name = 'Unknown';
  StreamController<List<Result<T>>>? streamController;
  Future<void> requestMore();
  bool get isfinished;
  bool get requesting;
  void reset();
}

class StreamSource<T> extends DataSource<T> {
  final Stream<List<T>> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
  @override
  bool requesting = false;
  StreamSource(this.loadmore);

  @override
  Future<void> requestMore() async {
    if (requesting) return;
    if (isfinished) return;
    if (streamController == null) return;
    requesting = true;
    final completer = Completer();
    loadmore(index++).listen(
      (e) {
        if (e.isEmpty) {
          isfinished = true;
          return;
        }
        streamController?.add(e.map((e) => Result.success(e)).toList());
      },
      onError: (e, stack) {
        try {
          streamController?.add(<Result<T>>[
            Result.failure(e as Exception, stack is StackTrace ? stack : null),
          ]);
        } finally {
          isfinished = true;
        }
      },
      cancelOnError: true,
      onDone: () {
        requesting = false;
        completer.complete();
      },
    );
    await completer.future;
  }

  @override
  void reset() {
    index = 0;
    isfinished = false;
    requesting = false;
  }

  @override
  String toString() {
    return 'AsyncStreamSource{loadmore: $loadmore, index: $index, isfinished: $isfinished, requesting: $requesting}';
  }

  @override
  bool operator ==(Object other) {
    return other is AsyncStreamSource<T> &&
        other.loadmore == loadmore &&
        other.index == index &&
        other.isfinished == isfinished &&
        other.requesting == requesting;
  }

  @override
  int get hashCode => Object.hash(loadmore, index, isfinished, requesting);
}

class SingleStreamSource<T> extends DataSource<T> {
  final Stream<T> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
  @override
  bool requesting = false;
  SingleStreamSource(this.loadmore);

  @override
  Future<void> requestMore() async {
    if (requesting) return;
    if (isfinished) return;
    if (streamController == null) return;
    requesting = true;
    var hasdelivered = false;
    final completer = Completer();
    loadmore(index++).listen(
      (e) {
        hasdelivered = true;
        streamController?.add([Result.success(e)]);
      },
      onError: (e, stack) {
        try {
          if (e is Exception) {
            streamController?.add(<Result<T>>[
              Result.failure(e, stack is StackTrace ? stack : null),
            ]);
          } else {
            streamController?.add(<Result<T>>[
              Result.failure(
                Exception(e.toString()),
                stack is StackTrace ? stack : null,
              ),
            ]);
          }
        } finally {
          isfinished = true;
        }
      },
      cancelOnError: true,
      onDone: () {
        completer.complete();
        requesting = false;
        if (!hasdelivered) {
          isfinished = true;
        }
      },
    );
    await completer.future;
  }

  @override
  void reset() {
    index = 0;
    isfinished = false;
    requesting = false;
  }

  @override
  String toString() {
    return 'SingleStreamSource{loadmore: $loadmore, index: $index, isfinished: $isfinished, requesting: $requesting}';
  }

  @override
  bool operator ==(Object other) {
    return other is SingleStreamSource<T> &&
        other.loadmore == loadmore &&
        other.index == index &&
        other.isfinished == isfinished &&
        other.requesting == requesting;
  }

  @override
  int get hashCode => Object.hash(loadmore, index, isfinished, requesting);
}

class AsyncStreamSource<T> extends DataSource<T> {
  final Future<Stream<List<T>>> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
  @override
  bool requesting = false;
  AsyncStreamSource(this.loadmore);

  @override
  Future<void> requestMore() async {
    if (requesting) return;
    if (isfinished) return;
    if (streamController == null) return;
    requesting = true;
    final completer = Completer();
    (await loadmore(index++)).listen(
      (e) {
        if (e.isEmpty) {
          isfinished = true;
          return;
        }
        streamController?.add(e.map((e) => Result.success(e)).toList());
      },
      onError: (e, stack) {
        try {
          streamController?.add(<Result<T>>[
            Result.failure(e as Exception, stack is StackTrace ? stack : null),
          ]);
        } finally {
          isfinished = true;
        }
      },
      cancelOnError: true,
      onDone: () {
        completer.complete();
        requesting = false;
      },
    );
    await completer.future;
  }

  @override
  void reset() {
    index = 0;
    isfinished = false;
    requesting = false;
  }

  @override
  String toString() {
    return 'AsyncSource{loadmore: $loadmore, index: $index, isfinished: $isfinished, requesting: $requesting}';
  }

  @override
  bool operator ==(Object other) {
    return other is AsyncSource<T> &&
        other.loadmore == loadmore &&
        other.index == index &&
        other.isfinished == isfinished &&
        other.requesting == requesting;
  }

  @override
  int get hashCode => Object.hash(loadmore, index, isfinished, requesting);
}

class AsyncSource<T> extends DataSource<T> {
  final Future<List<T>> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
  @override
  bool requesting = false;
  AsyncSource(this.loadmore);

  @override
  Future<void> requestMore() async {
    if (requesting) return;
    if (isfinished) return;
    if (streamController == null) return;
    requesting = true;
    try {
      final e = await loadmore(index++);
      if (e.isEmpty) {
        isfinished = true;
        requesting = false;
        return;
      }
      streamController?.add(e.map((e) => Result.success(e)).toList());
    } catch (e, stack) {
      try {
        streamController?.add(<Result<T>>[
          Result.failure(e as Exception, stack),
        ]);
      } catch (e1) {
        logger.e(
          'Error putting error $e1 into stream',
          error: e1,
          stackTrace: stack,
        );
      } finally {
        isfinished = true;
      }
    }
    requesting = false;
  }

  @override
  void reset() {
    index = 0;
    isfinished = false;
    requesting = false;
  }

  @override
  String toString() {
    return 'DataSource{loadmore: $loadmore, index: $index, isfinished: $isfinished, requesting: $requesting}';
  }

  @override
  bool operator ==(Object other) {
    return other is AsyncSource<T> &&
        other.loadmore == loadmore &&
        other.index == index &&
        other.isfinished == isfinished &&
        other.requesting == requesting;
  }

  @override
  int get hashCode => Object.hash(loadmore, index, isfinished, requesting);
}

class Page<T> {
  final List<T> items;
  final bool isLastPage;
  Page(this.items, this.isLastPage);
  Page.last(this.items) : isLastPage = true;
  Page.more(this.items) : isLastPage = false;
  Page.empty() : items = [], isLastPage = true;
}

class PageAsyncSource<T> extends DataSource<T> {
  final Future<Page<T>?> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
  @override
  bool requesting = false;
  PageAsyncSource(this.loadmore);

  @override
  Future<void> requestMore() async {
    if (requesting) return;
    if (isfinished) return;
    if (streamController == null) return;
    requesting = true;
    try {
      final e = await loadmore(index++);
      if (e == null) {
        isfinished = true;
        requesting = false;
        return;
      }
      if (e.isLastPage) {
        isfinished = true;
      }
      if (e.items.isEmpty) {
        isfinished = true;
        requesting = false;
        return;
      }
      streamController?.add(e.items.map((e) => Result.success(e)).toList());
    } catch (e, stack) {
      try {
        streamController?.add(<Result<T>>[
          Result.failure(e as Exception, stack),
        ]);
      } catch (e1) {
        logger.e(
          'Error putting error $e1 into stream',
          error: e1,
          stackTrace: stack,
        );
      } finally {
        isfinished = true;
      }
    }
    requesting = false;
  }

  @override
  void reset() {
    index = 0;
    isfinished = false;
    requesting = false;
  }

  @override
  String toString() {
    return 'DataSource{loadmore: $loadmore, index: $index, isfinished: $isfinished, requesting: $requesting}';
  }

  @override
  bool operator ==(Object other) {
    return other is AsyncSource<T> &&
        other.loadmore == loadmore &&
        other.index == index &&
        other.isfinished == isfinished &&
        other.requesting == requesting;
  }

  @override
  int get hashCode => Object.hash(loadmore, index, isfinished, requesting);
}

class DataSourceController<T> extends ChangeNotifier {
  final List<DataSource<T>> sources;
  final List<Result<T>> items = List.empty(growable: true);
  final StreamController<List<Result<T>>> streamController =
      StreamController<List<Result<T>>>();
  int index = 0;
  bool loading = false;
  bool finished = false;
  DataSourceController(this.sources) {
    for (final source in sources) {
      source.streamController = streamController;
    }
    streamController.stream.listen(
      (items) {
        this.items.addAll(items);
        notifyListeners();
      },
      onError: (e) {
        logger.e('DataSourceController failed stream: ', error: e);
      },
    );
  }

  Future<void> requestMore() async {
    if (loading || finished) return;
    loading = true;
    final futures = Future.wait(sources.map((source) => source.requestMore()));
    notifyListeners();
    await futures;
    loading = false;
    finished = sources.every((e) => e.isfinished);
    notifyListeners();
  }

  void reset() {
    for (final source in sources) {
      source.reset();
    }
    index = 0;
    finished = false;
    items.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
    streamController.close();
  }
}

class DynamicGrid<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? trace)?
  errorBuilder;
  final DataSourceController<T> controller;
  final double preload;
  final bool showDataSources;
  const DynamicGrid({
    super.key,
    required this.itemBuilder,
    this.errorBuilder,
    required this.controller,
    this.preload = 0.7,
    this.showDataSources = true,
  }) : assert(preload >= 0 && preload <= 1);

  @override
  _DynamicGridState createState() => _DynamicGridState<T>();
}

class _DynamicGridState<T> extends State<DynamicGrid<T>>
    with StateDisposeScopeMixin {
  late final ScrollController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller.hasClients) {
      // if (widget.controller.items.isEmpty) {
      //   widget.controller.requestMore();
      // }
      controller.jumpTo(0);
    }
  }

  @override
  void initState() {
    controller = ScrollController()..disposedBy(scope);
    loadMore();
    controller.addListener(() {
      loadMore();
    });
    super.initState();
  }

  Future<void> loadMore() async {
    while (shouldrequest) {
      await widget.controller.requestMore();
    }
  }

  bool get shouldrequest {
    if (!controller.hasClients) {
      return !widget.controller.loading && !widget.controller.finished;
    }
    return controller.position.pixels >=
            controller.position.maxScrollExtent * widget.preload &&
        !widget.controller.loading &&
        !widget.controller.finished;
  }

  @override
  Widget build(BuildContext context) {
    // loadMore();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showDataSources)
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.theme.colorScheme.surfaceContainer,
                  width: 1.5,
                ),
              ),
            ),
            child: Center(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, child) => ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...widget.controller.sources.map(
                      (e) => DionBadge(
                        color: e.name.color,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (e.isfinished)
                              const Icon(Icons.close, size: 20).paddingAll(2),
                            if (!e.isfinished && !e.requesting)
                              const Icon(Icons.check, size: 20).paddingAll(2),
                            if (e.requesting)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: const CircularProgressIndicator(
                                  color: Colors.white70,
                                  strokeWidth: 2,
                                ).paddingAll(2),
                              ),
                            Text(e.name).paddingAll(2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, child) => GridView.builder(
            padding: EdgeInsets.zero,
            controller: controller,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              childAspectRatio: 0.69,
              maxCrossAxisExtent: 220,
            ),
            itemCount:
                widget.controller.items.length +
                (widget.controller.finished ? 0 : 1),
            itemBuilder: (context, index) {
              if (index == widget.controller.items.length) {
                if (!widget.controller.loading) {
                  return DionTextbutton(
                    child: const Text('Load More'),
                    onPressed: () {
                      widget.controller.requestMore();
                    },
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }
              return widget.controller.items[index].fold(
                onSuccess: (item) => widget.itemBuilder(context, item),
                onFailure: (e, stacktrace) {
                  if (widget.errorBuilder == null) {
                    return ErrorDisplay(e: e, s: stacktrace);
                  }
                  return widget.errorBuilder!(context, e, stacktrace);
                },
              );
            },
          ).paddingAll(0).expanded(),
        ),
      ],
    );
  }
}

class DynamicList<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? trace)?
  errorBuilder;
  // final Widget Function(BuildContext context, S seperator) seperatorBuilder;
  // final S? Function(BuildContext context, T item, T next) shouldSeperate;
  final DataSourceController<T> controller;
  final double preload;
  final bool showDataSources;
  const DynamicList({
    super.key,
    required this.itemBuilder,
    this.errorBuilder,
    required this.controller,
    this.preload = 0.7,
    this.showDataSources = true,
    // required this.seperatorBuilder,
    // required this.shouldSeperate,
  }) : assert(preload >= 0 && preload <= 1);

  @override
  _DynamicListState createState() => _DynamicListState<T>();
}

class _DynamicListState<T> extends State<DynamicList<T>>
    with StateDisposeScopeMixin {
  late final Observer controllerObserver;
  late final ScrollController controller;

  @override
  void initState() {
    controller = ScrollController()..disposedBy(scope);
    controllerObserver = Observer(() {
      if (mounted) {
        setState(() {});
      }
    }, widget.controller)..disposedBy(scope);
    loadMore();
    controller.addListener(() {
      loadMore();
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controllerObserver.swapListener(widget.controller);
  }

  Future<void> loadMore() async {
    while (shouldrequest) {
      await widget.controller.requestMore();
    }
  }

  bool get shouldrequest {
    if (!controller.hasClients) {
      return !widget.controller.loading && !widget.controller.finished;
    }
    return controller.position.pixels >=
            controller.position.maxScrollExtent * widget.preload &&
        !widget.controller.loading &&
        !widget.controller.finished;
  }

  @override
  Widget build(BuildContext context) {
    loadMore();
    return Column(
      children: [
        if (widget.showDataSources)
          SizedBox(
            height: 40,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: [
                ...widget.controller.sources.map(
                  (e) => DionBadge(
                    color: e.name.color,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.isfinished)
                          const Icon(Icons.close, size: 20).paddingAll(2),
                        if (!e.isfinished && !e.requesting)
                          const Icon(Icons.check, size: 20).paddingAll(2),
                        if (e.requesting)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: const CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2,
                            ).paddingAll(2),
                          ),
                        Text(e.name).paddingAll(2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).paddingAll(5),
        ListView.builder(
          padding: EdgeInsets.zero,
          controller: controller,
          itemCount:
              widget.controller.items.length +
              (widget.controller.finished ? 0 : 1),
          itemBuilder: (context, index) {
            if (index == widget.controller.items.length) {
              if (!widget.controller.loading) {
                return DionTextbutton(
                  child: const Text('Load More'),
                  onPressed: () {
                    widget.controller.requestMore();
                  },
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            return widget.controller.items[index].fold(
              onSuccess: (item) => widget.itemBuilder(context, item),
              onFailure: (e, stacktrace) {
                if (widget.errorBuilder == null) {
                  return ErrorDisplay(e: e, s: stacktrace);
                }
                return widget.errorBuilder!(context, e, stacktrace);
              },
            );
          },
        ).expanded(),
      ],
    );
  }
}

class DynamicListSeperated<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? trace)?
  errorBuilder;
  final DataSourceController<T> controller;
  final double preload;
  final bool showDataSources;
  const DynamicListSeperated({
    super.key,
    required this.itemBuilder,
    this.errorBuilder,
    required this.controller,
    this.preload = 0.7,
    this.showDataSources = true,
  }) : assert(preload >= 0 && preload <= 1);

  @override
  _DynamicListSeperatedState createState() => _DynamicListSeperatedState<T>();
}

class _DynamicListSeperatedState<T> extends State<DynamicListSeperated<T>>
    with StateDisposeScopeMixin {
  late final ScrollController controller;
  late final Observer controllerObserver;

  @override
  void initState() {
    controller = ScrollController()..disposedBy(scope);
    controllerObserver = Observer(() {
      if (mounted) {
        setState(() {});
      }
    }, widget.controller)..disposedBy(scope);
    loadMore();
    controller.addListener(() {
      loadMore();
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controllerObserver.swapListener(widget.controller);
  }

  Future<void> loadMore() async {
    while (shouldrequest) {
      await widget.controller.requestMore();
    }
  }

  bool get shouldrequest {
    if (!controller.hasClients) {
      return !widget.controller.loading && !widget.controller.finished;
    }
    return controller.position.pixels >=
            controller.position.maxScrollExtent * widget.preload &&
        !widget.controller.loading &&
        !widget.controller.finished;
  }

  @override
  Widget build(BuildContext context) {
    loadMore();
    return Column(
      children: [
        if (widget.showDataSources)
          SizedBox(
            height: 40,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: [
                ...widget.controller.sources.map(
                  (e) => DionBadge(
                    color: e.name.color,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.isfinished)
                          const Icon(Icons.close, size: 20).paddingAll(2),
                        if (!e.isfinished && !e.requesting)
                          const Icon(Icons.check, size: 20).paddingAll(2),
                        if (e.requesting)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: const CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2,
                            ).paddingAll(2),
                          ),
                        Text(e.name).paddingAll(2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).paddingAll(5),
        ListView.builder(
          padding: EdgeInsets.zero,
          controller: controller,
          itemCount:
              widget.controller.items.length +
              (widget.controller.finished ? 0 : 1),
          itemBuilder: (context, index) {
            if (index == widget.controller.items.length) {
              if (!widget.controller.loading) {
                return DionTextbutton(
                  child: const Text('Load More'),
                  onPressed: () {
                    widget.controller.requestMore();
                  },
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            return widget.controller.items[index].fold(
              onSuccess: (item) => widget.itemBuilder(context, item),
              onFailure: (e, stacktrace) {
                if (widget.errorBuilder == null) {
                  return ErrorDisplay(e: e, s: stacktrace);
                }
                return widget.errorBuilder!(context, e, stacktrace);
              },
            );
          },
        ).paddingAll(10).expanded(),
      ],
    );
  }
}
