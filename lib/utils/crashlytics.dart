import 'dart:io';
import 'dart:isolate';

import 'package:dionysos/firebase_options.dart';
import 'package:dionysos/utils/log.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Boots Crashlytics for crash-only reporting.
///
/// Only actual force closes are reported: fatal isolate errors recorded here,
/// and native crashes — including hard aborts inside the Rust runtime —
/// captured by the Crashlytics NDK SDK. Non-fatal errors (Rust errors that
/// surface as Dart exceptions, framework errors, uncaught async errors) stay
/// local in the log store; users report those at their own discretion.
Future<void> initCrashlytics() async {
  // Crashlytics has no implementation on Windows/Linux; startup there must
  // stay telemetry-free and unaffected.
  if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;
  try {
    // Also serves as the per-isolate guard: workmanager reuses one background
    // isolate across task runs, and only the first run must attach the
    // fatal-error listener below.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Fires when an unhandled error is about to terminate the isolate — the
      // one Dart-side signal of a force close. Crashlytics delivers the
      // report on the next launch.
      final fatalErrorPort = RawReceivePort((List<dynamic> pair) async {
        final dynamic stack = pair.elementAtOrNull(1);
        await FirebaseCrashlytics.instance.recordError(
          pair.first,
          stack is StackTrace ? stack : StackTrace.fromString('$stack'),
          fatal: true,
          reason: 'fatal isolate error',
        );
      });
      Isolate.current.addErrorListener(fatalErrorPort.sendPort);
    }
  } catch (e, stack) {
    logger.w(
      'Crashlytics unavailable; crashes will not be reported',
      error: e,
      stackTrace: stack,
    );
  }
}
