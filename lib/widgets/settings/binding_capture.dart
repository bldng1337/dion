import 'package:dionysos/data/settings/binding.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<InputBinding?> showBindingCapture(BuildContext context) {
  return showDialog<InputBinding?>(
    context: context,
    builder: (context) => const _BindingCaptureDialog(),
  );
}

class _BindingCaptureDialog extends StatefulWidget {
  const _BindingCaptureDialog();

  @override
  State<_BindingCaptureDialog> createState() => _BindingCaptureDialogState();
}

class _BindingCaptureDialogState extends State<_BindingCaptureDialog> {
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DionRadius.large),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(DionSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.keyboard_command_key,
                    size: 20,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: DionSpacing.sm),
                  Text(
                    'Add binding',
                    style: DionTypography.titleMedium(context.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: DionSpacing.md),
              Text(
                'Press a key combination, or perform a gesture.',
                style: DionTypography.bodyMedium(context.textSecondary),
              ),
              const SizedBox(height: DionSpacing.md),
              _CaptureSurface(onCaptured: _handleCaptured),
              const SizedBox(height: DionSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCaptured(InputBinding binding) {
    if (_captured || !mounted) return;
    _captured = true;
    Navigator.of(context).pop(binding);
  }
}

class _CaptureSurface extends StatefulWidget {
  final ValueChanged<InputBinding> onCaptured;
  const _CaptureSurface({required this.onCaptured});

  @override
  State<_CaptureSurface> createState() => _CaptureSurfaceState();
}

class _CaptureSurfaceState extends State<_CaptureSurface> {
  final GlobalKey _surfaceKey = GlobalKey();

  Offset? _downLocal;
  Offset? _downGlobal;
  Size? _surfaceSize;

  static const double _swipeMinDistance = 48;

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
    if (isModifierKey(event.logicalKey)) return false;
    final hk = HardwareKeyboard.instance;
    widget.onCaptured(
      KeyBind(
        event.logicalKey,
        ctrl: hk.isControlPressed,
        alt: hk.isAltPressed,
        shift: hk.isShiftPressed,
        meta: hk.isMetaPressed,
      ),
    );
    return true;
  }

  InputZone _zoneOf(Offset? local) {
    final size = _surfaceSize ?? Size.zero;
    if (local == null) return InputZone.full;
    return InputZone.fromPosition(local, size);
  }

  void _onPointerDown(PointerDownEvent event) {
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    _surfaceSize = box?.size ?? Size.zero;
    _downLocal = event.localPosition;
    _downGlobal = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _downGlobal;
    if (down == null) return;
    final delta = event.position - down;
    if (delta.distance >= _swipeMinDistance) {
      final direction = _classifySwipe(delta);
      widget.onCaptured(SwipeGesture(direction, zone: _zoneOf(_downLocal)));
    }
    _downGlobal = null;
    _downLocal = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) {
        _downGlobal = null;
        _downLocal = null;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            widget.onCaptured(TapGesture(1, zone: _zoneOf(_downLocal))),
        onDoubleTapDown: (details) => _downLocal = details.localPosition,
        onDoubleTap: () =>
            widget.onCaptured(TapGesture(2, zone: _zoneOf(_downLocal))),
        onLongPressStart: (details) => _downLocal = details.localPosition,
        onLongPress: () =>
            widget.onCaptured(LongPressGesture(zone: _zoneOf(_downLocal))),
        child: Container(
          key: _surfaceKey,
          height: 120,
          decoration: BoxDecoration(
            color: context.surfaceMuted,
            borderRadius: DionRadius.medium,
            border: Border.all(color: context.borderColor),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 28,
                color: context.textTertiary,
              ),
              const SizedBox(height: DionSpacing.xs),
              Text(
                'Tap, swipe, or press a key',
                style: DionTypography.bodySmall(context.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

SwipeDirection _classifySwipe(Offset delta) {
  if (delta.dx.abs() >= delta.dy.abs()) {
    return delta.dx >= 0 ? SwipeDirection.right : SwipeDirection.left;
  }
  return delta.dy >= 0 ? SwipeDirection.down : SwipeDirection.up;
}
