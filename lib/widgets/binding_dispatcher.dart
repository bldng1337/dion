import 'package:dionysos/data/settings/binding.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:flutter/gestures.dart';
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

  // Drag recognizers ignore mouse pointers by default; swipes were
  // previously raw Listener events, so keep mouse working.
  static const Set<PointerDeviceKind> _dragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };

  Offset? _downLocal;
  Offset? _tapDownLocal;
  Offset? _dragStartLocal;
  Offset? _dragLocal;
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

  bool _isTypingContext() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    if (focusContext.widget is EditableText) return true;
    return focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Only act while this dispatcher's route is the topmost one; shortcuts
    // must not fire while a dialog or a pushed settings page overlays the
    // player, and must not hijack keys while the user is typing.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    if (_isTypingContext()) return false;
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

  void _onDragStart(DragStartDetails details) {
    final box = _gestureKey.currentContext?.findRenderObject() as RenderBox?;
    _size = box?.size ?? Size.zero;
    _dragStartLocal = details.localPosition;
    _dragLocal = details.localPosition;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragLocal = details.localPosition;
  }

  void _onDragEnd(DragEndDetails details) {
    final start = _dragStartLocal;
    final current = _dragLocal;
    _dragStartLocal = null;
    _dragLocal = null;
    if (start == null || current == null) return;
    final delta = current - start;
    if (delta.distance >= _swipeMinDistance) {
      _triggerGesture(SwipeGesture(_classifySwipe(delta), zone: _zoneOf(start)));
    }
  }

  void _onDragCancel() {
    _dragStartLocal = null;
    _dragLocal = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(widget.actions.map((a) => a.setting)),
      builder: (context, _) {
        // Swipes are detected with arena-based drag recognizers instead of
        // raw Listener events so that a scrollable which consumes the drag
        // (inner recognizers win the arena) does not also trigger a page
        // jump - touching a scroll list used to scroll *and* swipe.
        return RawGestureDetector(
          key: _gestureKey,
          behavior: HitTestBehavior.translucent,
          gestures: {
            VerticalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  VerticalDragGestureRecognizer
                >(
                  () => VerticalDragGestureRecognizer(
                    supportedDevices: _dragDevices,
                  ),
                  (instance) {
                    instance
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel;
                  },
                ),
            HorizontalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  HorizontalDragGestureRecognizer
                >(
                  () => HorizontalDragGestureRecognizer(
                    supportedDevices: _dragDevices,
                  ),
                  (instance) {
                    instance
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel;
                  },
                ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) => _tapDownLocal = d.localPosition,
            onTap: () {
              _triggerGesture(
                TapGesture(1, zone: _zoneOf(_tapDownLocal)),
              );
              _tapDownLocal = null;
            },
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
