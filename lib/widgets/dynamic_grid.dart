import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/result.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

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
        streamController?.add(e.map((e) => Result.value(e)).toList());
      },
      onError: (e) {
        streamController?.add(<Result<T>>[Result.error(e)]);
        isfinished = true;
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
        streamController?.add([Result.value(e)]);
      },
      onError: (e, stack) {
        streamController?.add(<Result<T>>[
          Result.error(e, trace: stack is StackTrace ? stack : null),
        ]);
        isfinished = true;
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
        streamController?.add(e.map((e) => Result.value(e)).toList());
      },
      onError: (e, stack) {
        streamController?.add(<Result<T>>[
          Result.error(e, trace: stack is StackTrace ? stack : null),
        ]);
        isfinished = true;
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
      streamController?.add(e.map((e) => Result.value(e)).toList());
    } catch (e, stack) {
      streamController?.add(<Result<T>>[Result.error(e, trace: stack)]);
      isfinished = true;
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
    final futures = Future.wait(
      sources.map((source) => source.requestMore()),
    );
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
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? trace,
  )? errorBuilder;
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
  void initState() {
    controller = ScrollController()..disposedBy(scope);
    Observer(
      () {
        if (mounted) {
          setState(() {});
        }
      },
      [widget.controller],
    );
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
                          const Icon(
                            Icons.close,
                            size: 20,
                          ).paddingAll(2),
                        if (!e.isfinished && !e.requesting)
                          const Icon(
                            Icons.check,
                            size: 20,
                          ).paddingAll(2),
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
        GridView.builder(
          padding: EdgeInsets.zero,
          controller: controller,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            childAspectRatio: 0.69,
            maxCrossAxisExtent: 220,
          ),
          itemCount: widget.controller.items.length +
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
            return widget.controller.items[index].build(
                (item) => widget.itemBuilder(context, item), (e, stacktrace) {
              if (widget.errorBuilder == null) {
                return ErrorDisplay(
                  e: e,
                  s: stacktrace,
                );
              }
              return widget.errorBuilder!(context, e, stacktrace);
            });
          },
        ).paddingAll(10).expanded(),
      ],
    );
  }
}
