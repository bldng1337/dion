import 'package:dionysos/main.dart';
import 'package:flutter/material.dart';
import 'package:rdion_runtime/rdion_runtime.dart' show ToastKind;

void showToast(String message, ToastKind kind) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  if (message.isEmpty) {
    messenger.hideCurrentSnackBar();
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                _iconFor(kind),
                color: _colorFor(kind),
                size: 20,
              ),
            ),
            Expanded(child: Text(message)),
          ],
        ),
        duration: _durationFor(kind),
        backgroundColor: _snackbarBackgroundFor(kind),
      ),
    );
}

Duration _durationFor(ToastKind kind) {
  switch (kind) {
    case ToastKind.error:
      return const Duration(seconds: 6);
    case ToastKind.warning:
      return const Duration(seconds: 5);
    case ToastKind.info:
    case ToastKind.success:
      return const Duration(seconds: 3);
  }
}

Color _colorFor(ToastKind kind) {
  switch (kind) {
    case ToastKind.error:
      return Colors.redAccent;
    case ToastKind.warning:
      return Colors.orangeAccent;
    case ToastKind.success:
      return Colors.greenAccent;
    case ToastKind.info:
      return Colors.lightBlueAccent;
  }
}

const Color _baseSnackbarBackground = Color(0xFF1F1F1F);

Color _snackbarBackgroundFor(ToastKind kind) {
  return Color.alphaBlend(
    _colorFor(kind).withValues(alpha: 0.22),
    _baseSnackbarBackground,
  );
}

IconData _iconFor(ToastKind kind) {
  switch (kind) {
    case ToastKind.error:
      return Icons.error_outline;
    case ToastKind.warning:
      return Icons.warning_amber;
    case ToastKind.success:
      return Icons.check_circle_outline;
    case ToastKind.info:
      return Icons.info_outline;
  }
}
