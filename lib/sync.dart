import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:isar/isar.dart';
import 'util/file_utils.dart';

Future<Directory?> getSyncPath() {
  Directory? dir=SyncSetting.dir.value;
  if (dir == null) {
    return Future.value(null);
  }
  return dir.csub("dionsync");
}

void dosync() async {
  Directory? d = await getSyncPath();
  if (d == null) {
    return;
  }
  File f = d.getFile("$deviceId.sync");
  await for (final file in d.list()) {
    if (file is! File || file.getExtension() != ".sync" || f.getBasePath() == file.getBasePath()) {
      continue;
    }
    final jsonsync = json.decode(await file.readAsString());
    for (final entry in jsonsync["entries"]) {
      final url = entry["url"] as String;
      final extname = entry["extname"] as String;
      final epdata = entry["epdata"] as Map<String,dynamic>;
      final categories = listcast<String>(entry["categories"]);
      EntrySaved? s =
          await isar.entrySaveds.filter().urlEqualTo(url).findFirst();
      s ??=
          (await ExtensionManager().searchExtensionbyname(extname)?.detail(url))?.toSaved();
      if (s == null) {
        continue;
      }
      for(final ep in epdata.entries){
        s.getEpdata(int.parse(ep.key)).applyJSON(ep.value);
      }
      // for(final cat in categories){
      //   Category? c=await isar.categorys.where().filter().nameEqualTo(cat).findFirst();
      //   c ??= Category()..name=cat;
      //   await isar.writeTxn(() => isar.categorys.put(c!));
      //   s.category.add(c);
      // }
      await isar.writeTxn(() => isar.entrySaveds.put(s!));
    }
  }
}

void savesync() async {
  Directory? d = await getSyncPath();
  if (d == null) {
    return;
  }
  File f = d.getFile("$deviceId.sync");
  await f.create();
  Map<String, dynamic> jsond = {};
  List<EntrySaved> entr = await isar.entrySaveds.where().anyId().findAll();
  jsond["entries"] =
      List.generate(entr.length, (index) => entr[index].toJSON());
  // print(jsond);
  await f.writeAsString(json.encode(jsond));
}
