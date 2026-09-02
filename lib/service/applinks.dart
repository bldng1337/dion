import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:dionysos/utils/app_links_helper.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';

class AppLinksService {
  static const String customScheme = 'dion';

  late final AppLinks _appLinks;

  Uri? initialLink;

  Uri? _pendingLink;

  final _linkController = StreamController<Uri>.broadcast();

  Stream<Uri> get linkStream {
    late final StreamController<Uri> controller;
    StreamSubscription<Uri>? subscription;
    controller = StreamController<Uri>(
      onListen: () {
        final pending = _pendingLink;
        _pendingLink = null;
        if (pending != null) {
          controller.add(pending);
        }
        subscription = _linkController.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

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
        _pendingLink = initialLink;
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

    onLinkReceived?.call(uri);
  }
}
