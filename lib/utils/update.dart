import 'dart:io';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/build_info.dart';
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
  // Nightly builds inject the full version string (incl. commit) at build
  // time; prefer it so the commit hash is reflected in the running version.
  if (BuildInfo.hasInfo) {
    return Version.parse(BuildInfo.version);
  }
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
  final String? commit;

  Update(
    this.link,
    this.version,
    this.date,
    this.body,
    this.assets, {
    this.commit,
  });

  /// Parses a GitHub release into an [Update], or `null` for releases whose
  /// `tag_name` is not a parseable semver (e.g. the rolling `nightly`
  /// release, which has no `v`-prefixed version tag). Without this guard the
  /// unparseable tag would throw and crash the whole update check for
  /// stable/beta users.
  static Update? fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String;
    final versionStr = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final Version version;
    try {
      version = Version.parse(versionStr);
    } on FormatException {
      return null;
    }
    final publishedAt = json['published_at'];
    return Update(
      json['html_url'] as String,
      version,
      publishedAt == null
          ? DateTime.now()
          : DateTime.parse(publishedAt as String),
      (json['body'] as String?) ?? '',
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
    if (update.commit != null) {
      // Nightly builds are tracked by commit hash; patch/minor notification
      // toggles don't apply. Suppress only re-prompts for the same commit.
      if (settings.update.lastnotifiednightly.value == update.commit) {
        return;
      }
    } else {
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
  }
  if (update.commit != null) {
    settings.update.lastnotifiednightly.value = update.commit!;
  } else {
    settings.update.lastnotified.value = update.version;
  }
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
  final versions = (res.bodyToJson as List<dynamic>)
      .map((e) => Update.fromJson(e as Map<String, dynamic>))
      .whereType<Update>()
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
  return newversion;
}

class NightlyManifest {
  final Version version;
  final String baseVersion;
  final String commit;
  final DateTime commitDate;

  const NightlyManifest(
    this.version,
    this.baseVersion,
    this.commit,
    this.commitDate,
  );

  factory NightlyManifest.fromJson(Map<String, dynamic> json) {
    return NightlyManifest(
      Version.parse(json['version'] as String),
      json['base_version'] as String,
      json['commit'] as String,
      DateTime.parse(json['commit_date'] as String),
    );
  }
}

Future<Update?> checkNightlyUpdate() async {
  final network = await locateAsync<NetworkService>();
  final res = await network.client.get(
    'https://api.github.com/repos/bldng1337/dion/releases/tags/nightly',
    headers: const HttpHeaders.map({
      HttpHeaderName.userAgent: 'bldng1337/dion',
    }),
  );
  final release = res.bodyToJson as Map<String, dynamic>;
  final assets = (release['assets'] as List<dynamic>)
      .map(
        (e) => UpdateAssets(
          e['browser_download_url'] as String,
          e['name'] as String,
        ),
      )
      .toList();
  final manifestAsset = assets.firstWhere(
    (e) => e.filename == 'nightly.json',
    orElse: () => throw StateError('nightly.json not found on nightly release'),
  );

  final manifestRes = await network.client.get(
    manifestAsset.url,
    headers: const HttpHeaders.map({
      HttpHeaderName.userAgent: 'bldng1337/dion',
    }),
  );
  final manifest = NightlyManifest.fromJson(
    manifestRes.bodyToJson as Map<String, dynamic>,
  );

  if (manifest.commit == BuildInfo.commit) {
    return null;
  }

  final link = release['html_url'] as String;
  return Update(
    link,
    manifest.version,
    manifest.commitDate,
    'Nightly build ${manifest.commit} (${manifest.baseVersion})',
    assets.where((e) => e.filename != 'nightly.json').toList(),
    commit: manifest.commit,
  );
}

enum CheckResult { skipped, upToDate, updateAvailable, error }

Future<CheckResult> checkVersion({bool force = false}) async {
  if (!force) {
    if (kDebugMode) {
      return CheckResult.skipped;
    }
  }
  try {
    logger.i('Checking for updates');
    final isNightlyChannel =
        settings.update.channel.value == UpdateChannel.nightly;
    final update = isNightlyChannel
        ? await checkNightlyUpdate()
        : await checkUpdate();
    if (update == null) return CheckResult.upToDate;
    logger.i('New update available: ${update.version}');
    await notify(update, force: force);
    return CheckResult.updateAvailable;
  } catch (e, stack) {
    logger.e('Failed to check for updates', error: e, stackTrace: stack);
    return CheckResult.error;
  }
}
