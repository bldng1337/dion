import 'dart:async';

class KeyedMutex {
  final _tails = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() action) {
    final previous = _tails[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _tails[key] = completer.future;
    return previous
        .then((_) => action())
        .whenComplete(() {
          if (identical(_tails[key], completer.future)) {
            _tails.remove(key);
          }
          completer.complete();
        });
  }
}
