import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';

class LoadingBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final Widget Function(BuildContext context, T value) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? error;
  const LoadingBuilder({
    required this.future,
    required this.builder,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final error = this.error ??
        (context, error, stackTrace) => ErrorDisplay(e: error, s: stackTrace);
    final loading = this.loading ??
        (context) => const Center(
              child: CircularProgressIndicator(),
            );
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return error(context, snapshot.error ?? Error(), snapshot.stackTrace);
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return loading(context);
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}
