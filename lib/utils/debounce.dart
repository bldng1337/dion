import 'dart:async';
import 'package:flutter/foundation.dart';

class Debouncer {
  final Duration duration;
  final VoidCallback action;
  Timer? _timer;
  bool _disposed = false;

  Debouncer({required this.duration, required this.action});

  /// (Re-)schedules the action, replacing any pending call.
  void run() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs a pending action immediately, if any.
  void flush() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    action();
  }

  /// Drops a pending action without running it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
    _disposed = true;
  }
}
