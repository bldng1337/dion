import 'dart:io';

import 'package:restart_app/restart_app.dart';

Future<void> restartApp() async {
  if (Platform.isWindows) {
    // restart_app has no Windows implementation
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
  await Restart.restartApp();
}
