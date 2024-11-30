import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/result.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

abstract class DataSource<T> {
  String name = 'Unknown';
  StreamController<List<Result<T>>>? streamController;
  Future<void> requestMore();
  bool get isfinished;
  bool get requesting;
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
}

class AsyncSource<T> extends DataSource<T> {
  final Future<List<T>> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
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
}

class DynamicGrid<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? trace,
  )? errorBuilder;
  final List<DataSource<T>> sources;
  final double preload;
  final bool showDataSources;
  const DynamicGrid({
    super.key,
    required this.itemBuilder,
    this.errorBuilder,
    required this.sources,
    this.preload = 0.7,
    this.showDataSources = true,
  }) : assert(preload >= 0 && preload <= 1);

  @override
  _DynamicGridState createState() => _DynamicGridState<T>();
}

class _DynamicGridState<T> extends State<DynamicGrid<T>>
    with StateDisposeScopeMixin {
  late final StreamController<List<Result<T>>> streamController;
  late final List<Result<T>> items;
  int index = 0;
  late final ScrollController controller;
  bool loading = false;
  bool finished = false;

  Future<void> loadMore() async {
    if (loading || finished) return;
    loading = true;
    for (final source in widget.sources) {
      source.streamController ??= streamController;
    }
    final futures = Future.wait(
      widget.sources.map((source) => Future.value(source.requestMore())),
    );
    if (mounted) {
      setState(() {});
    }
    await futures;
    loading = false;
    finished = widget.sources.every((e) => e.isfinished);
    if (mounted) {
      setState(() {});
    }
    try{
      if (controller.position.pixels >=
          controller.position.maxScrollExtent * widget.preload) {
        loadMore();
      }
    }catch(e,stack){
    }
  }

  @override
  void initState() {
    items = [];
    controller = ScrollController()..disposedBy(scope);
    streamController = StreamController()..disposedBy(scope);
    for (final source in widget.sources) {
      source.streamController = streamController;
    }
    streamController.stream.listen(
      (items) {
        this.items.addAll(items);
        if (mounted) {
          setState(() {});
        }
      },
      onError: (e) {
        logger.e(e);
      },
    );
    loadMore();
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent * widget.preload) {
        loadMore();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showDataSources)
          SizedBox(
            height: 30,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: [
                ...widget.sources.map(
                  (e) => DionBadge(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.isfinished)
                          const Icon(
                            Icons.check,
                            size: 15,
                          ).paddingAll(2),
                        if (e.requesting)
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: const CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 1,
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
          itemCount: items.length + (finished ? 0 : 1),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return items[index].build(
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
