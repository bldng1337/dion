import 'dart:convert';
import 'dart:io';

import 'package:dionysos/Entry.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

init() async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [EntrySavedSchema],
    directory: dir.path,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await ExtensionManager().finit;
  // await init();

  dynamic js=json.decode('{"b":2}');
  print(js["a"]);
  
  // EntryDetail? e=await (await ExtensionManager().browse(0, SortMode.latest).first)[0].detailed();
  // if (e!=null) {
    // EntrySaved esa=EntrySaved.fromEntry(e);
    // await isar.writeTxn(() async {
    //   await isar.entrySaveds.put(esa);
    // });
    // final entries = await Isar.getInstance()?.entrySaveds.where()
    // .offset(0)
    // .limit(10)
    // .findAll();
    // if(entries!=null){
      // entries.removeLast();
      // await Isar.getInstance()?.writeTxn(() async {
      //   await Isar.getInstance()?.entrySaveds.deleteAll(entries.map((e) => e.id).toList());
      // });
      // print(entries.length);
      
    // isar.entrySaveds.get
    // }
  // }
}

