import 'dart:io';

import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/network_manager.dart';
import 'package:dionysos/util/settingsapi.dart';
import 'package:dionysos/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:internet_file/internet_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

Future<Version> getVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (packageInfo.buildNumber.isNotEmpty) {
    return Version.parse('${packageInfo.version}+${packageInfo.buildNumber}');
  } else {
    return Version.parse(packageInfo.version);
  }
}

const updateUrl = 'https://api.github.com/repos/bldng1337/dion/releases/latest';

class Update {
  final String link;
  final String body;
  final Version currentversion;
  final Version version;
  final DateTime date;
  Update(this.link, this.version, this.currentversion, this.date, this.body);
}

const lastver = SettingString('versionnotified', '');

bool hasNotifiedForUpdate(Version version) {
  if (kDebugMode) {
    return true;
  }
  try {
    final lastversion = Version.parse(lastver.value);
    lastver.setvalue(version.toString());
    return lastversion.compareTo(version) == 0;
    // ignore: empty_catches
  } catch (err) {}
  lastver.setvalue(version.toString());
  return false;
}

class UpdatingDialog extends StatefulWidget {
  final Update update;
  const UpdatingDialog({super.key, required this.update});

  @override
  State<UpdatingDialog> createState() => _UpdatingDialogState();
}

class _UpdatingDialogState extends State<UpdatingDialog> {
  double progress = 0;
  @override
  void initState() {
    doUpdate(
      widget.update,
      (p) => setState(() {
        progress = p;
      }),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Downloading new version...',
        textAlign: TextAlign.center,
      ),
      content: Center(
        child: CircularProgressIndicator(
          value: progress,
        ),
      ),
    );
  }
}

Future<void> doUpdate(
  Update u,
  void Function(double progress) onprogress,
) async {
  final file = (await (await getApplicationCacheDirectory()).csub('update'))
      .getFile('install.${u.link.split('.').last}');
  if (await file.exists()) {
    await file.delete();
  }
  await file.writeAsBytes(
    await InternetFile.get(
      u.link,
      progress: (receivedLength, contentLength) =>
          onprogress(receivedLength / contentLength.toDouble()),
    ),
  );
  switch (getPlatform()) {
    case CPlatform.windows:
      await Process.start(file.absolute.path, [
        '/SILENT',
        '/LANG=english',
        '/SP',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ]);
    case CPlatform.android:
      await InstallPlugin.install(file.absolute.path);
    case _:
      file.delete();
  }
  exit(0);
}

Future<Update?> checkUpdate() async {
  try {
    final res = (await NetworkManager().dio.get(updateUrl)).data
        as Map<String, dynamic>;
    final currversion = await getVersion();
    final version = Version.parse((res['tag_name'] as String).substring(1));
    if (version.compareTo(currversion) <= 0) {
      return null;
    }
    final date = DateTime.parse(res['published_at'] as String);
    final downloadurl = switch (getPlatform()) {
      CPlatform.android => (res['assets'] as List<dynamic>).firstWhereOrNull(
          (element) =>
              (element['name'] as String).endsWith('apk') &&
              (element['content_type'] as String) ==
                  'application/vnd.android.package-archive',
        )?['browser_download_url'] as String?,
      CPlatform.windows => (res['assets'] as List<dynamic>).firstWhereOrNull(
          (element) =>
              (element['name'] as String).endsWith('exe') &&
              (element['content_type'] as String) == 'raw',
        )?['browser_download_url'] as String?,
      _ => null,
    };
    if (downloadurl == null) {
      return null;
    }
    return Update(
        downloadurl, version, currversion, date, res['body'] as String,);
  } catch (e) {
    return null;
  }
}
