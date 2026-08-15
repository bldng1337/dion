import 'package:flutter/widgets.dart';

extension SafeSetStateExt<T extends StatefulWidget> on State<T> {
  void safeSetState([VoidCallback? fn]) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() => fn?.call());
    }
  }
}
