import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/result.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

abstract class DataSource<T> {
  StreamController<List<Result<T>>>? streamController;
  Future<void> requestMore();
  bool get isfinished;
}

class StreamSource<T> extends DataSource<T> {
  final Stream<List<T>> Function(int index) loadmore;
  @override
  bool isfinished = false;
  int index = 0;
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
        streamController?.add(<Result<T>>[Result.error(e as Exception)]);
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
          Result.error(e as Exception, trace: stack as StackTrace),
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
          Result.error(e as Exception, trace: stack as StackTrace),
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
        return;
      }
      streamController?.add(e.map((e) => Result.value(e)).toList());
    } catch (e, stack) {
      streamController
          ?.add(<Result<T>>[Result.error(e as Exception, trace: stack)]);
      isfinished = true;
    }
    requesting = false;
  }
}

class DynamicGrid<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(
      BuildContext context, Exception error, StackTrace? trace,)? errorBuilder;
  final List<DataSource<T>> sources;
  final double preload;
  const DynamicGrid({
    super.key,
    required this.itemBuilder,
    this.errorBuilder,
    required this.sources,
    this.preload = 0.9,
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
    await Future.wait(
        widget.sources.map((source) => Future.value(source.requestMore())),);
    loading = false;
    finished = widget.sources.every((e) => e.isfinished);
    if (finished) {
      if (mounted) {
        setState(() {});
      }
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
    // TODO: Maybe make this more efficient
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent * widget.preload) {
        loadMore();
      }
    }).disposedBy(scope);
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
    // return Container(color: Colors.red,);
    return GridView.builder(
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
        return items[index].build((item) => widget.itemBuilder(context, item),
            (e, stacktrace) {
          if (widget.errorBuilder == null) {
            return ErrorDisplay(
              e: e,
              s: stacktrace,
            );
          }
          return widget.errorBuilder!(context, e, stacktrace);
        });
      },
    ).paddingAll(10);
  }
}
