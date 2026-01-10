import 'package:flutter/widgets.dart';

mixin class KeyedChangeNotifier<T> implements Listenable {
  final Map<T, ChangeNotifier> _listeners = {};
  final _notifier = ChangeNotifier();

  void addKeyedListener(T key, VoidCallback listener) {
    if (!_listeners.containsKey(key)) {
      _listeners[key] = ChangeNotifier();
    }
    _listeners[key]!.addListener(listener);
  }

  void removeKeyedListener(T key, VoidCallback listener) {
    if (_listeners.containsKey(key)) {
      _listeners[key]!.removeListener(listener);
    }
  }

  Listenable getListenable(T key) {
    if (!_listeners.containsKey(key)) {
      _listeners[key] = ChangeNotifier();
    }
    return _listeners[key]!;
  }

  @override
  void addListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  void notifyListeners(Iterable<T> keys) {
    for (final key in keys) {
      if (_listeners.containsKey(key)) {
        // Doesn't matter here as we are using the raw ChangeNotifier maybe we could make a custom class implementing Listenable but it should function the same regardless
        _listeners[key]!.notifyListeners();
      }
    }
    _notifier.notifyListeners();
  }
}
