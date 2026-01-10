import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:dionysos/utils/app_links_helper.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';

class AppLinksService {
  static const String customScheme = (kDebugMode || kProfileMode)
      ? 'diondev'
      : 'dion'; //Technically this wouldnt work right when debugging on android/iOS since those would still use the production scheme, but if that is needed one can just change it manually in android/app/src/main/AndroidManifest.xml

  late final AppLinks _appLinks;

  Uri? initialLink;

  Stream<Uri> get linkStream => _linkController.stream;
  final _linkController = StreamController<Uri>.broadcast();

  Future<void> Function(Uri)? onLinkReceived;

  AppLinksService() {
    _appLinks = AppLinks();
  }

  static Future<void> ensureInitialized() async {
    final service = AppLinksService();
    await service.init();
    register<AppLinksService>(service);
    logger.i('Initialised AppLinksService!');
  }

  Future<void> init() async {
    try {
      initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        logger.i('Received initial link: $initialLink');
        _handleLink(initialLink!);
      }
    } catch (e, stack) {
      logger.e('Failed to get initial link', error: e, stackTrace: stack);
    }

    _appLinks.uriLinkStream.listen(
      (uri) {
        logger.i('Received deep link: $uri');
        _handleLink(uri);
      },
      onError: (error) {
        logger.e('Error receiving deep link', error: error);
      },
    );

    if (Platform.isWindows && (kDebugMode || kProfileMode)) {
      try {
        await _registerWindowsScheme();
      } catch (e, stack) {
        logger.e(
          'Failed to register Windows scheme for debugging',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  Future<void> _registerWindowsScheme() async {
    if (await AppLinksHelper.isSchemeRegistered(customScheme)) {
      return;
    }
    logger.i('Registering Windows scheme for debugging: $customScheme');
    await AppLinksHelper.registerScheme(customScheme);
  }

  void _handleLink(Uri uri) {
    _linkController.add(uri);

    if (onLinkReceived != null) {
      onLinkReceived!(uri);
    }
  }
}
