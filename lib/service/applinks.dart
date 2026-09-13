import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/app_links_helper.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/views/extension/permission_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// Deep links use the `dion://` scheme:
///
/// - `dion://<view>` opens a view, e.g. `dion://library`,
///   `dion://settings/downloads`, `dion://search/<query>` or
///   `dion://extension/<id>`.
/// - `dion://entry?extension=<id>&uid=<uid>` opens an entry's detail page.
/// - `dion://extension/install?url=<encoded url>` installs an extension from
///   a direct link after user confirmation.
/// - `dion://repo/add?url=<encoded url>` adds an extension repository.
///
/// Links with any other host (e.g. OAuth callbacks of the form
/// `dion://<domain>/oauth`) are left to their [linkStream] listeners.
class AppLinksService {
  static const String customScheme = 'dion';

  /// Route prefixes a view link may target. Routes that consume in-memory
  /// objects from extra (`/detail`, `/view`, `/quotes`) are excluded so a
  /// foreign link cannot push a view that crashes on a missing extra.
  static const _viewLinkPrefixes = [
    '/library',
    '/calendar',
    '/activity',
    '/browse',
    '/manage',
    '/search',
    '/extension',
    '/settings',
    '/dev',
  ];

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
        // Feed linkStream listeners (e.g. the OAuth callback flow) before
        // routing the link through the app-level dispatcher.
        _linkController.add(uri);
        handleLink(uri);
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

  Uri? takePendingLink() {
    final link = _pendingLink;
    _pendingLink = null;
    return link;
  }

  Future<void> handleLink(Uri uri, {bool coldStart = false}) async {
    // Everything below needs services that only exist after the loading
    // screen; park the link until loading replays it.
    if (!has<Database>() || !has<ExtensionService>()) {
      logger.i('App not ready; deferring deep link $uri');
      _pendingLink = uri;
      return;
    }
    switch (uri.host) {
      case 'entry':
        await _openEntry(uri, coldStart: coldStart);
      case 'extension' when uri.path == '/install':
        await _installExtension(uri, coldStart: coldStart);
      case 'repo' when uri.path == '/add':
        await _addRepository(uri, coldStart: coldStart);
      default:
        _openView(uri);
    }
  }

  void _openView(Uri uri) {
    final path = '/${uri.host}${uri.path}';
    if (!_viewLinkPrefixes.any(path.startsWith)) {
      // Unknown hosts may belong to linkStream listeners such as the OAuth
      // callback flow, so they are ignored here rather than reported.
      logger.i('Ignoring deep link $uri: not an app view');
      return;
    }
    logger.i('Navigating to $path from deep link $uri');
    appRouter?.go(path);
  }

  Future<void> _openEntry(Uri uri, {required bool coldStart}) async {
    final uid = uri.queryParameters['uid'];
    final extensionId = uri.queryParameters['extension'];
    if (uid == null ||
        uid.isEmpty ||
        extensionId == null ||
        extensionId.isEmpty) {
      showToast('Invalid entry link', rust.ToastKind.error);
      return;
    }
    final saved = await locate<Database>().getSavedById(rust.EntryId(uid: uid));
    final entry = saved ?? _placeholderEntry(uid, extensionId);
    if (entry == null) {
      showToast(
        'Cannot open entry: extension $extensionId is not installed',
        rust.ToastKind.error,
      );
      return;
    }
    // A cold-start link replaces the loading view, later links open on top
    // like an in-app tap would.
    if (coldStart) {
      appRouter?.go('/detail', extra: [entry]);
    } else {
      appRouter?.push('/detail', extra: [entry]);
    }
  }

  Entry? _placeholderEntry(String uid, String extensionId) {
    if (locate<ExtensionService>().tryGetExtension(extensionId) == null) {
      return null;
    }
    // Only the id is load-bearing: the detail view fetches the full entry
    // from the extension by id.
    return EntryImpl(
      rust.Entry(
        id: rust.EntryId(uid: uid),
        url: '',
        title: '',
        mediaType: rust.MediaType.unknown,
      ),
      extensionId,
    );
  }

  Future<void> _installExtension(Uri uri, {required bool coldStart}) async {
    final url = uri.queryParameters['url'];
    if (url == null || url.isEmpty) {
      showToast(
        'Extension install link is missing the url',
        rust.ToastKind.error,
      );
      return;
    }
    final context = navigatorKey.currentContext;
    if (context == null) {
      logger.w('Extension install link ignored: no navigator context');
      return;
    }
    if (coldStart) {
      appRouter?.go('/manage');
    }
    if (!await showExtensionLinkInstallDialog(context, url)) {
      return;
    }
    showToast('Installing extension…', rust.ToastKind.info);
    try {
      await locate<ExtensionService>().install(url);
      showToast('Extension installed', rust.ToastKind.success);
    } catch (e, stack) {
      logger.e(
        'Failed to install extension from $url',
        error: e,
        stackTrace: stack,
      );
      showToast('Failed to install extension', rust.ToastKind.error);
    }
  }

  Future<void> _addRepository(Uri uri, {required bool coldStart}) async {
    final url = uri.queryParameters['url'];
    if (url == null || url.isEmpty) {
      showToast('Repository link is missing the url', rust.ToastKind.error);
      return;
    }
    final repos = settings.extension.repositories.value;
    if (repos.contains(url)) {
      showToast('Repository already added', rust.ToastKind.warning);
      return;
    }
    settings.extension.repositories.value = [...repos, url];
    showToast('Repository added', rust.ToastKind.success);
    if (coldStart) {
      appRouter?.go('/manage');
    }
  }

  Future<void> _registerWindowsScheme() async {
    if (await AppLinksHelper.isSchemeRegistered(customScheme)) {
      return;
    }
    logger.i('Registering Windows scheme for debugging: $customScheme');
    await AppLinksHelper.registerScheme(customScheme);
  }
}
