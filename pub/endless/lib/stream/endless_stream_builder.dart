import 'dart:async';

import 'package:endless/endless_state_property.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EndlessStreamBuilder<T> extends StatefulWidget {
  final void Function() loadMore;
  final Function(Set<EndlessState> states)? onStateChange;
  final Stream<List<T>> stream;
  final Widget Function({
    required List<T> items,
    required Set<EndlessState> states,
    required void Function() loadMore,
  }) builder;
  final EndlessStreamController<T>? controller;

  /// Whether loadMore() should immediately be called upon subscribing to the stream.
  final bool loadOnSubscribe;

  const EndlessStreamBuilder({
    required this.loadMore,
    required this.builder,
    required this.stream,
    this.onStateChange,
    this.controller,
    this.loadOnSubscribe = true,
    key,
  }) : super(key: key);

  @override
  _EndlessStreamBuilderState<T> createState() => _EndlessStreamBuilderState();
}

class _EndlessStreamBuilderState<T> extends State<EndlessStreamBuilder<T>> {
  List<T> _items = [];
  bool _isLoading = false;
  bool _canLoadMore = true;
  StreamSubscription? _streamSubscription;
  bool _pendingLazyClear = false;
  bool _isPaused = false;
  Set<EndlessState>? _prevStates;

  @override
  void didUpdateWidget(covariant EndlessStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.stream != widget.stream) {
      _subscribeToStream();
    }
  }

  @override
  initState() {
    super.initState();

    final controller = widget.controller;

    if (controller != null) {
      controller.remove = (T item) {
        setState(() {
          _items.remove(item);
        });
      };
      controller.loadMore = () {
        _loadMore();
      };
      controller.clear = ({bool lazy = false}) {
        _clear(lazy);
      };
      controller.pause = () {
        if (_canLoadMore) {
          // No need to call setState as _disableLoading will subsequently do it
          _isPaused = true;
          _disableLoading();
        }
      };
      controller.resume = () {
        if (_isPaused) {
          setState(() {
            _canLoadMore = true;
            _isPaused = false;
          });
        }
      };
      controller.isPaused = () {
        return _isPaused;
      };
      controller.isMounted = () {
        return mounted;
      };
    }

    _subscribeToStream();
  }

  @override
  dispose() {
    super.dispose();
    _cancelSubscription();
  }

  _cancelSubscription() async {
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }
  }

  _subscribeToStream() async {
    setState(() {
      _canLoadMore = true;
      _isLoading = widget.loadOnSubscribe;
      _pendingLazyClear = true;
    });

    await _cancelSubscription();

    _streamSubscription = widget.stream.listen((items) {
      setState(() {
        if (_pendingLazyClear) {
          _items = [...items];
          _pendingLazyClear = false;
        } else {
          _items = [
            ..._items,
            ...items,
          ];
        }
        _isLoading = false;
      });
    })
      ..onDone(_disableLoading);

    if (widget.loadOnSubscribe) {
      widget.loadMore();
    }
  }

  _disableLoading() {
    setState(() {
      _canLoadMore = false;
      _isLoading = false;
    });
  }

  _loadMore() async {
    if (_canLoadMore && !_isLoading) {
      setState(() {
        _isLoading = true;
      });
      widget.loadMore();
    }
  }

  _clear([lazy = false]) {
    if (lazy) {
      setState(() {
        _pendingLazyClear = true;
      });
    } else {
      setState(() {
        _items = [];
        _pendingLazyClear = false;
      });
    }
  }

  Set<EndlessState> _resolveStates() {
    final states = <EndlessState>{};

    if (_isLoading) {
      states.add(EndlessState.loading);
    }

    if (!_canLoadMore) {
      states.add(EndlessState.done);
    }

    if (_items.isEmpty) {
      states.add(EndlessState.empty);
    }

    if (_pendingLazyClear) {
      states.add(EndlessState.willClear);
    }

    return states;
  }

  @override
  Widget build(context) {
    final states = _resolveStates();

    if (widget.onStateChange != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_prevStates == null || !setEquals(_prevStates, states)) {
          widget.onStateChange!(states);
        }
        _prevStates = states;
      });
    }

    return widget.builder(
      states: _resolveStates(),
      items: _items,
      loadMore: _loadMore,
    );
  }
}
