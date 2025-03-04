import 'dart:io';

enum CPlatform { ios, android, macos, windows, fuchsia, unknown }

CPlatform getPlatform() {
  if (Platform.isIOS) {
    return CPlatform.ios;
  } else if (Platform.isAndroid) {
    return CPlatform.android;
  } else if (Platform.isMacOS) {
    return CPlatform.macos;
  } else if (Platform.isWindows) {
    return CPlatform.windows;
  } else if (Platform.isFuchsia) {
    return CPlatform.fuchsia;
  } else {
    return CPlatform.unknown;
  }
}
