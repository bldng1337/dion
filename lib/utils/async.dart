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
  Object? _error;
  StackTrace? _stackTrace;
  bool _complete = false;

  Completable();

  @override
  void complete([FutureOr<T>? value]) {
    if (_complete) {
      throw StateError('Future already completed');
    }
    _complete = true;
    if (value is Future<T>) {
      _future = value.then((v) {
        _value = v;
        return v;
      });
      return;
    }
    _value = value;
    _future = Future.value(value);
  }

  @override
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (_complete) {
      throw StateError('Future already completed');
    }
    _complete = true;
    _error = error;
    _stackTrace = stackTrace;
    _future = Future.error(error, stackTrace);
    _value = null;
  }

  /// The resolved value, if completed successfully with a synchronous value.
  /// Returns null if not yet completed, completed with an error, or
  /// completed with a Future that has not yet resolved.
  T? get value => _value;

  /// The error this completer was completed with, if any.
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

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
