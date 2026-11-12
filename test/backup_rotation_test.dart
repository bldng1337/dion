import 'dart:io';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/backup.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferenceService();
    await prefs.init();
    register<PreferenceService>(prefs);
  });

  test('file names round-trip through parse', () {
    final time = DateTime(2026, 11, 12, 9, 5, 7);
    final plain = BackupFile.parse(File(BackupFile.fileName(time)))!;
    expect(plain.time, time);
    expect(plain.label, isNull);

    final labelled = BackupFile.parse(
      File(BackupFile.fileName(time, label: 'pre-update-v2.0.0-beta.61+a/b')),
    )!;
    expect(labelled.time, time);
    expect(labelled.label, 'pre-update-v2.0.0-beta.61+ab');
  });

  test('exports and unrelated files are not treated as backups', () {
    expect(BackupFile.parse(File(exportFileName())), isNull);
    expect(BackupFile.parse(File('dion-backup-notes.txt')), isNull);
    expect(
      BackupFile.parse(File('${BackupFile.fileName(DateTime.now())}.part')),
      isNull,
    );
  });

  test('purge keeps only the newest backups and leaves other files', () async {
    final dir = await Directory.systemTemp.createTemp('dion_backup_test');
    addTearDown(() => dir.delete(recursive: true));

    final base = DateTime(2026);
    for (var i = 0; i < 6; i++) {
      await dir
          .getFile(BackupFile.fileName(base.add(Duration(days: i))))
          .writeAsString('$i');
    }
    final foreign = dir.getFile('my-notes.txt');
    await foreign.writeAsString('keep me');
    final stalePart = dir.getFile('${BackupFile.fileName(base)}.part');
    await stalePart.writeAsString('partial');
    await stalePart.setLastModified(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    settings.backup.keep.value = 3;
    await purgeBackups(dir);

    final remaining = await listBackups(dir);
    expect(remaining.map((b) => b.time), [
      base.add(const Duration(days: 5)),
      base.add(const Duration(days: 4)),
      base.add(const Duration(days: 3)),
    ]);
    expect(await foreign.exists(), isTrue);
    expect(await stalePart.exists(), isFalse);
  });
}
