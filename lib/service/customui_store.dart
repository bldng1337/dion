import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:dionysos/utils/log.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class CustomUIStore implements Disposable {
  CustomUIStore({
    Duration watchdogInterval = _defaultWatchdogInterval,
    int hangThreshold = _defaultHangThreshold,
  })  : _watchdogInterval = watchdogInterval,
        _hangThreshold = hangThreshold {
    _watchdog = Timer.periodic(_watchdogInterval, (_) => _tick());
  }

  /// How often the watchdog scans for hanging (subscriber-less) entries.
  static const Duration _defaultWatchdogInterval = Duration(seconds: 60);

  /// How many consecutive scans an entry can survive without subscribers before being evicted. Mitigates an entry being insta evicted by unlucky timing of the watchdog tick and a subscriber's unsubscribe.
  static const int _defaultHangThreshold = 2;

  final Duration _watchdogInterval;
  final int _hangThreshold;

  final Map<String, _Entry> _entries = {};
  late Timer _watchdog;
  bool _disposed = false;

  int _nextToken = 0;

  String? get(String key) {
    if (_disposed) return null;
    return _entries[key]?.value;
  }

  Future<void> set(String key, String value) async {
    if (_disposed) return;
    var entry = _entries[key];
    if (entry == null) {
      entry = _Entry(value: value);
      _entries[key] = entry;
    } else {
      entry.value = value;
      entry.hangEpoch = 0;
    }
    // Snapshot the callbacks so a callback that unsubscribes during iteration
    // cannot mutate the map under us.
    final callbacks = List<VoidCallback>.of(entry.subscribers.values);
    for (final cb in callbacks) {
      try {
        cb();
      } catch (e, st) {
        logger.e('CustomUIStore subscriber for "$key" threw', error: e, stackTrace: st);
      }
    }
  }

  Object subscribe(String key, void Function() onNotify) {
    if (_disposed) return _DisposedToken.instance;
    var entry = _entries[key];
    if (entry == null) {
      entry = _Entry(value: null);
      _entries[key] = entry;
    }
    entry.hangEpoch = 0;
    final token = _Token(_nextToken++);
    entry.subscribers[token] = onNotify;
    if (entry.value != null) {
      try {
        onNotify();
      } catch (e, st) {
        logger.e('CustomUIStore initial fire for "$key" threw', error: e, stackTrace: st);
      }
    }
    return token;
  }

  void unsubscribe(String key, Object token) {
    if (_disposed) return;
    final entry = _entries[key];
    if (entry == null) return;
    if (token is _Token) {
      entry.subscribers.remove(token);
    }
  }

  void _tick() {
    if (_disposed) return;
    // Eviction pass
    _entries.removeWhere((key, entry) {
      if (entry.subscribers.isNotEmpty) {
        entry.hangEpoch = 0;
        return false;
      }
      if (entry.value == null) {
        return true; // never written; nothing to retain
      }
      entry.hangEpoch += 1;
      if (entry.hangEpoch >= _hangThreshold) {
        return true;
      }
      return false;
    });
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    if (_watchdog.isActive) _watchdog.cancel();
    _entries.clear();
    return Future.value();
  }
}

class _Entry {
  // null means "subscribed to but never written".
  String? value;
  int hangEpoch = 0;
  final Map<_Token, void Function()> subscribers = {};

  _Entry({required this.value});
}

class _Token {
  const _Token(this.id);
  final int id;
}

class _DisposedToken {
  const _DisposedToken();
  static const _DisposedToken instance = _DisposedToken();
}

class CustomUIChangeBus implements Disposable {
  final Map<String, _Broadcaster> _broadcasters = {};
  bool _disposed = false;
  int _nextToken = 0;

  void notify(String key) {
    if (_disposed) return;
    _broadcasters[key]?._fire();
  }

  /// Registers [onNotify] for [key]. Returns an opaque token to pass to
  /// [unsubscribe].
  Object subscribe(String key, void Function() onNotify) {
    if (_disposed) return _DisposedToken.instance;
    var b = _broadcasters[key];
    if (b == null) {
      b = _Broadcaster();
      _broadcasters[key] = b;
    }
    final token = _Token(_nextToken++);
    b.listeners[token] = onNotify;
    return token;
  }

  void unsubscribe(String key, Object token) {
    if (_disposed) return;
    final b = _broadcasters[key];
    if (b == null) return;
    if (token is _Token) {
      b.listeners.remove(token);
    }
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    _broadcasters.clear();
    return Future.value();
  }
}

class _Broadcaster {
  final Map<_Token, void Function()> listeners = {};

  void _fire() {
    final snapshot = List<VoidCallback>.of(listeners.values);
    for (final cb in snapshot) {
      try {
        cb();
      } catch (err,stack) {
        logger.e('CustomUIChangeBus subscriber threw', error: err, stackTrace: stack);
        // A failing listener must not break notification of the others.
      }
    }
  }
}
