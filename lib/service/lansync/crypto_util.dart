import 'dart:convert';

import 'package:pointycastle/export.dart';

int sasCode(String localFingerprint, String remoteFingerprint) {
  final pair = [localFingerprint, remoteFingerprint]..sort();
  final input = utf8.encode(pair.join());
  final digest = Digest('SHA-256').process(input);
  // First 8 bytes as big-endian int, mod 10^6.
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | digest[i];
  }
  // Ensure 6 digits with leading zeros.
  return value % 1000000;
}

String sasCodeString(String localFingerprint, String remoteFingerprint) {
  final code = sasCode(localFingerprint, remoteFingerprint);
  return code.toString().padLeft(6, '0');
}
