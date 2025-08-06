import 'dart:io';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/platform.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/update_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rhttp/rhttp.dart';

Future<Version> getVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (packageInfo.buildNumber.isNotEmpty) {
    return Version.parse('${packageInfo.version}+${packageInfo.buildNumber}');
  } else {
    return Version.parse(packageInfo.version);
  }
}

class UpdateAssets {
  final String filename;
  final String url;

  const UpdateAssets(this.url, this.filename);
}

class Update {
  final String link;
  final String body;
  final Version version;
  final DateTime date;
  final List<UpdateAssets> assets;

  Update(this.link, this.version, this.date, this.body, this.assets);

  factory Update.fromJson(Map<String, dynamic> json) {
    return Update(
      json['html_url'] as String,
      Version.parse((json['tag_name'] as String).substring(1)),
      DateTime.parse(json['published_at'] as String),
      json['body'] as String,
      (json['assets'] as List<dynamic>)
          .map(
            (e) => UpdateAssets(
              e['browser_download_url'] as String,
              e['name'] as String,
            ),
          )
          .toList(),
    );
  }

  @override
  String toString() {
    return 'Update(link: $link, version: $version, date: $date, body: $body)';
  }
}

Future<void> notify(Update update, {bool force = false}) async {
  if (!force) {
    if (settings.update.lastnotified.value.canonicalizedVersion ==
        update.version.canonicalizedVersion) {
      return;
    }
    final version = await getVersion();
    final versiondiff = (
      (update.version.major - version.major).abs().sign,
      (update.version.minor - version.minor).abs().sign,
      (update.version.patch - version.patch).abs().sign,
    );
    if (!settings.update.patch.value && versiondiff == (0, 0, 1)) {
      return;
    }
    if (!settings.update.minor.value && versiondiff == (0, 1, 0)) {
      return;
    }
  }
  settings.update.lastnotified.value = update.version;
  await showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => UpdateDialog(update: update),
  );
  logger.i('Notifying user of update');
}

Future<void> downloadUpdate(
  Update update, {
  Function(double? progress, String phase)? onReceiveProgress,
}) async {
  final asset = switch (getPlatform()) {
    CPlatform.android => update.assets.firstWhere(
      (e) => e.filename.endsWith('.apk'),
    ),
    CPlatform.windows => update.assets.firstWhere(
      (e) => e.filename.endsWith('.exe'),
    ),
    _ => throw UnimplementedError('Unsupported platform ${getPlatform()}'),
  };
  final dirprovider = locate<DirectoryProvider>();
  final file = dirprovider.temppath.getFile(asset.filename);
  await InternetFile.streamToFile(
    asset.url,
    file,
    headers: {'userAgent': 'bldng1337/dion'},
    onReceiveProgress: (prog) =>
        onReceiveProgress?.call(prog, 'Downloading ${asset.filename}'),
  );
  onReceiveProgress?.call(null, 'Installing ${asset.filename}');
  switch (getPlatform()) {
    case CPlatform.android:
      await InstallPlugin.install(file.absolute.path);
    case CPlatform.windows:
      await Process.start(file.absolute.path, [
        '/SILENT',
        '/LANG=english',
        '/SP',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ]);
    default:
      throw UnimplementedError('Unsupported platform ${getPlatform()}');
  }
}

Future<Update?> checkUpdate() async {
  final network = await locateAsync<NetworkService>();
  final version = await getVersion();
  final res = await network.client.get(
    'https://api.github.com/repos/bldng1337/dion/releases',
    headers: const HttpHeaders.map({
      HttpHeaderName.userAgent: 'bldng1337/dion',
    }),
  );
  var versions = (res.bodyToJson as List<dynamic>)
      .map((e) => Update.fromJson(e as Map<String, dynamic>))
      .toList();
  logger.i('Found ${versions.length} update(s)');
  versions = versions
      .where(
        (e) => e.version.canonicalizedVersion != version.canonicalizedVersion,
      )
      .toList();
  logger.i('Found ${versions.length} update(s)');
  for (final e in versions) {
    logger.i(
      'Checking ${e.version.canonicalizedVersion}>=$version ${e.version >= version}',
    );
  }
  versions = versions.where((e) => e.version >= version).toList();
  logger.i('Found ${versions.length} update(s)');
  versions = versions
      .where(
        (e) =>
            !e.version.isPreRelease ||
            (settings.update.channel.value == UpdateChannel.beta),
      )
      .toList();
  logger.i('Found ${versions.length} update(s)');
  if (versions.isEmpty) {
    return null;
  }
  final newversion = versions.first;
  return newversion;
}

Future<void> checkVersion({bool force = false}) async {
  if (!force) {
    if (kDebugMode) {
      return;
    }
  }
  try {
    logger.i('Checking for updates');
    final update = await checkUpdate();
    if (update == null) return;
    logger.i('New update available: ${update.version}');
    await notify(update, force: force);
  } catch (e, stack) {
    logger.e('Failed to check for updates', error: e, stackTrace: stack);
  }
}
