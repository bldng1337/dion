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

Future<void> notify(Update update) async {
  if (settings.update.lastnotified.value.canonicalizedVersion ==
      update.version.canonicalizedVersion) {
    return;
  }
  if (kDebugMode) {
    return;
  }
  settings.update.lastnotified.value = update.version;
  logger.i('New update available: ${update.version}');
  await showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => UpdateDialog(update: update),
  );
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
  await InternetFile.save(
    asset.url,
    file,
    headers: const HttpHeaders.map({
      HttpHeaderName.userAgent: 'bldng1337/dion',
    }),
    onReceiveProgress: (current, max) =>
        onReceiveProgress?.call(current / max, 'Downloading ${asset.filename}'),
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
  final versions = (res.bodyToJson as List<dynamic>)
      .map((e) => Update.fromJson(e as Map<String, dynamic>))
      .where(
        (e) => e.version.canonicalizedVersion != version.canonicalizedVersion,
      )
      .where((e) => e.version >= version)
      .where(
        (e) =>
            !e.version.isPreRelease ||
            (settings.update.channel.value == UpdateChannel.beta),
      )
      .toList();
  if (versions.isEmpty) {
    return null;
  }
  final newversion = versions.first;
  if (!newversion.version.isPreRelease ||
      (newversion.version.major == version.major &&
          (newversion.version.minor == version.minor ||
              !settings.update.minor.value) &&
          (newversion.version.patch == version.patch ||
              !settings.update.patch.value))) {
    return null;
  }
  return newversion;
}

Future<void> checkVersion() async {
  try {
    final update = await checkUpdate();
    if (update == null) return;
    notify(update);
  } catch (e, stack) {
    logger.e('Failed to check for updates', error: e, stackTrace: stack);
  }
}
