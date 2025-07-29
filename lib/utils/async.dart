import 'dart:async';

import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';

extension FutureExtension<T> on Future<T> {
  Completable<T> get asCompletable {
    return Completable()..complete(this);
  }
}

extension FutureOrExtension<T> on FutureOr<T> {
  Completable<T> get asCompletable {
    return Completable()..complete(this);
  }
}

class Completable<T> implements Completer<T> {
  Future<T>? _future;
  T? _value;
  bool _complete = false;

  Completable();

  @override
  void complete([FutureOr<T>? value]) {
    if (_future != null) {
      throw StateError('Future already completed');
    }
    if (value is Future<T>) {
      _future = value;
      value.then((value) {
        _value = value;
        _complete = true;
      });
      return;
    }
    _value = value;
    _future = Future.value(value);
    _complete = true;
  }

  @override
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (_future != null) {
      throw StateError('Future already completed');
    }
    //TODO: Maybe we should also provide a sync way to get the error
    _future = Future.error(error, stackTrace);
    _value = null;
    _complete = true;
  }

  T? get value => _value;

  @override
  Future<T> get future => _future!;

  @override
  bool get isCompleted => _complete;
}

class LoadingBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final Widget Function(BuildContext context, T value) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  error;
  const LoadingBuilder({
    required this.future,
    required this.builder,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final error =
        this.error ??
        (context, error, stackTrace) => ErrorDisplay(e: error, s: stackTrace);
    final loading =
        this.loading ??
        (context) => const Center(child: CircularProgressIndicator());
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
