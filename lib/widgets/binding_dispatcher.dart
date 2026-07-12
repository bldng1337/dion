import 'package:dionysos/data/settings/binding.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BindingAction {
  final Setting<List<InputBinding>, dynamic> setting;
  final VoidCallback onTrigger;

  const BindingAction({required this.setting, required this.onTrigger});
}

class BindingDispatcher extends StatefulWidget {
  final List<BindingAction> actions;
  final Widget child;

  const BindingDispatcher({
    super.key,
    required this.actions,
    required this.child,
  });

  @override
  State<BindingDispatcher> createState() => _BindingDispatcherState();
}

class _BindingDispatcherState extends State<BindingDispatcher> {
  final GlobalKey _gestureKey = GlobalKey();

  static const double _swipeMinDistance = 64;

  Offset? _downGlobal;
  Offset? _downLocal;
  Size? _size;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    for (final action in widget.actions) {
      for (final binding in action.setting.value) {
        if (binding is KeyBind && binding.matchesKey(event.logicalKey)) {
          action.onTrigger();
          return true; // consume
        }
      }
    }
    return false;
  }

  InputZone _zoneOf(Offset? local) {
    final size = _size ?? Size.zero;
    if (local == null) return InputZone.full;
    return InputZone.fromPosition(local, size);
  }

  void _triggerGesture(InputBinding candidate) {
    for (final action in widget.actions) {
      for (final binding in action.setting.value) {
        if (_gestureEquals(binding, candidate)) {
          action.onTrigger();
          return;
        }
      }
    }
  }

  bool _gestureEquals(InputBinding a, InputBinding b) {
    if (a is SwipeGesture && b is SwipeGesture) {
      return a.direction == b.direction && a.zone.matches(b.zone);
    }
    if (a is TapGesture && b is TapGesture) {
      return a.count == b.count && a.zone.matches(b.zone);
    }
    if (a is LongPressGesture && b is LongPressGesture) {
      return a.zone.matches(b.zone);
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    final box = _gestureKey.currentContext?.findRenderObject() as RenderBox?;
    _size = box?.size ?? Size.zero;
    _downGlobal = event.position;
    _downLocal = event.localPosition;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downGlobal;
    if (down == null) return;
    final delta = event.position - down;
    if (delta.distance >= _swipeMinDistance) {
      final direction = _classifySwipe(delta);
      _triggerGesture(SwipeGesture(direction, zone: _zoneOf(_downLocal)));
    }
    _downGlobal = null;
    _downLocal = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(widget.actions.map((a) => a.setting)),
      builder: (context, _) {
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) {
            _downGlobal = null;
            _downLocal = null;
          },
          child: GestureDetector(
            key: _gestureKey,
            behavior: HitTestBehavior.translucent,
            onTap: () =>
                _triggerGesture(TapGesture(1, zone: _zoneOf(_downLocal))),
            onDoubleTapDown: (d) => _downLocal = d.localPosition,
            onDoubleTap: () =>
                _triggerGesture(TapGesture(2, zone: _zoneOf(_downLocal))),
            onLongPressStart: (d) => _downLocal = d.localPosition,
            onLongPress: () =>
                _triggerGesture(LongPressGesture(zone: _zoneOf(_downLocal))),
            child: widget.child,
          ),
        );
      },
    );
  }
}

SwipeDirection _classifySwipe(Offset delta) {
  if (delta.dx.abs() >= delta.dy.abs()) {
    return delta.dx >= 0 ? SwipeDirection.right : SwipeDirection.left;
  }
  return delta.dy >= 0 ? SwipeDirection.down : SwipeDirection.up;
}
