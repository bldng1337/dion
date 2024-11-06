import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class DynamicGrid<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Stream<List<T>> Function() loadmore;
  final double preload;
  const DynamicGrid({
    super.key,
    required this.itemBuilder,
    required this.loadmore,
    this.preload = 0.9,
  }) : assert(preload >= 0 && preload <= 1);

  @override
  _DynamicGridState createState() => _DynamicGridState<T>();
}

class _DynamicGridState<T> extends State<DynamicGrid<T>>
    with StateDisposeScopeMixin {
  late final StreamController<List<T>> streamController;
  late final List<T> items;
  late final ScrollController controller;
  bool loading = false;

  Future<void> loadMore() async {
    if (loading) return;
    loading = true;
    await streamController.addStream(widget.loadmore());
    loading = false;
  }

  @override
  void initState() {
    items = [];
    controller = ScrollController()..disposedBy(scope);
    streamController = StreamController()..disposedBy(scope);
    streamController.stream.listen((items) {
      this.items.addAll(items);
      setState(() {});
    }, onError: (e) {
      logger.e(e);
    },);
    loadMore();
    controller.addListener(() {
      if (controller.position.pixels >
          controller.position.maxScrollExtent * widget.preload) {
        loadMore();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        childAspectRatio: 0.69,
        maxCrossAxisExtent: 220,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        return widget.itemBuilder(context, items[index]);
      },
    ).paddingAll(10);
  }
}
