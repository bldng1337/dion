import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class Observer implements Disposable {
  final Function() callback;
  final bool callIndirectly;
  Listenable listener;
  Observer(this.callback, this.listener, {bool callOnInit = true, this.callIndirectly=true}) {
    if (callOnInit) {
      _call();
    }
    listener.addListener(_call);
  }

  void _call() {
    if(callIndirectly){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callback();
      });
    }else{
      callback();
    }
  }

  void swapListener(Listenable newListener) {
    if(listener==newListener) return;
    listener.removeListener(_call);
    listener = newListener;
    listener.addListener(_call);
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    listener.removeListener(_call);
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
