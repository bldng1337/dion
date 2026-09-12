import 'dart:io';

import 'package:flutter/services.dart';

class AndroidStorage {
  static const MethodChannel _channel = MethodChannel('dionysos/storage');

  static bool get isSupported => Platform.isAndroid;

  static Future<int> get sdkInt async {
    if (!isSupported) return 0;
    return await _channel.invokeMethod<int>('getSdkInt') ?? 0;
  }

  static Future<bool> hasStorageAccess({bool write = false}) async {
    if (!isSupported) return true;
    return await _channel.invokeMethod<bool>('hasStorageAccess', {
          'write': write,
        }) ??
        false;
  }

  static Future<bool> requestStoragePermission({bool write = false}) async {
    if (!isSupported) return true;
    return await _channel.invokeMethod<bool>('requestStoragePermission', {
          'write': write,
        }) ??
        false;
  }

  static Future<bool> openAllFilesAccessSettings() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('openAllFilesAccessSettings') ??
        false;
  }
}
