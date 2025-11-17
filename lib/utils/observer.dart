import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class Observer implements Disposable {
  final Function() callback;
  late final Listenable notifier;
  Observer(
    this.callback,
    List<ChangeNotifier> notifiers, {
    bool callOnInit = true,
  }) {
    if (notifiers.length > 1) {
      notifier = Listenable.merge(notifiers);
    } else {
      notifier = notifiers[0];
    }
    if (callOnInit) {
      callback();
    }
    notifier.addListener(callback);
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    notifier.removeListener(callback);
    return Future.value();
  }
}

class KeyObserver implements Disposable {
  final Function(KeyEvent event) callback;
  KeyObserver(this.callback) {
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  bool _handleKey(KeyEvent event) {
    callback(event);
    return false;
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    return Future.value();
  }
}
