import 'package:flutter/widgets.dart';

class _NotifiableChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

mixin class KeyedChangeNotifier<T> implements Listenable {
  final Map<T, _NotifiableChangeNotifier> _listeners = {};
  final _notifier = _NotifiableChangeNotifier();

  void addKeyedListener(T key, VoidCallback listener) {
    _listeners
        .putIfAbsent(key, () => _NotifiableChangeNotifier())
        .addListener(listener);
  }

  void removeKeyedListener(T key, VoidCallback listener) {
    _listeners[key]?.removeListener(listener);
  }

  Listenable getListenable(T key) {
    return _listeners.putIfAbsent(key, () => _NotifiableChangeNotifier());
  }

  Listenable get globalListenable => _notifier;

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
      _listeners[key]?.notify();
    }
    _notifier.notify();
  }
}
