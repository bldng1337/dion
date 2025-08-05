import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class Storage extends StatelessWidget {
  const Storage({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      child: ListView(
        children: [
          DionTextbutton(
            child: const Text('Create Backup'),
            onPressed: () async {
              final archive = await createBackup();
              final String? dir = await getDirectoryPath();
              if (dir == null) return;
              final file = File('$dir/dion.dpkg');
              await file.create(recursive: true);
              await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
            },
          ),
          DionTextbutton(
            child: const Text('Apply Backup'),
            onPressed: () async {
              const XTypeGroup typeGroup = XTypeGroup(
                label: 'Dion Package',
                extensions: <String>['dpkg'],
              );
              final List<XFile> files = await openFiles(
                acceptedTypeGroups: <XTypeGroup>[typeGroup],
              );
              for (final file in files) {
                final archive = ZipDecoder().decodeBytes(
                  await file.readAsBytes(),
                );
                await applyBackup(archive);
              }
            },
          ),
          DionTextbutton(
            child: const Text('Clear Database'),
            onPressed: () async {
              await locate<Database>().clear();
            },
          ),
          DionTextbutton(
            child: const Text('Clear Settings'),
            onPressed: () async {
              for (final setting in preferenceCollection.settings) {
                setting.value = setting.intialValue;
              }
            },
          ),
        ],
      ),
    );
  }
}

const archiveVersion = 1;
Future<Archive> createBackup() async {
  final db = locate<Database>();
  final entries = [];
  while (entries.length % 100 == 0) {
    final entriesdb = await db.getEntries(0, 100).toList();
    entries.addAll(entriesdb.map((e) => e.toJson()));
  }
  final archive = Archive();
  archive.addFile(
    ArchiveFile.string(
      'dionmeta.json',
      json.encode({
        'version': archiveVersion,
        'content': ['entries'],
      }),
    ),
  );
  archive.addFile(ArchiveFile.string('entrydata.json', json.encode(entries)));
  return archive;
}

Future<void> applyBackup(Archive archive) async {
  final db = locate<Database>();
  final entries =
      json.decode(
            String.fromCharCodes(archive.findFile('entrydata.json')!.content),
          )
          as List<dynamic>;
  for (final entry in entries) {
    final entrydata = await EntrySaved.fromJson(entry as Map<String, dynamic>);
    await db.updateEntry(entrydata);
  }
}
