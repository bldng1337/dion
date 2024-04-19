import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:flutter_js/quickjs/ffi.dart';


class ExtensionManager {
  static final ExtensionManager _instance = ExtensionManager._internal();
  List<Extension> loaded = List.empty(growable: true);
  late Future<void> finit;

  ExtensionManager._internal() {
    finit = init();
  }

  Future<void> init() async {
    await reload();
  }

  Future<void> reload() async {
    List<Extension> newloaded = List.empty(growable: true);
    Directory d = await getPath("extension");
    await for (final file in d.list()) {
      if (file is File && file.getExtension() == ".dion.js") {
        try {
          newloaded.add(await Extension(file).init());
        } catch (e) {
          print(e);
        }
      }
    }
    for (var e in loaded) {
      e.dispose();
    }
    loaded = newloaded;
  }

  Stream<List<Entry>> browse(int page, SortMode sort,
      {bool Function(Extension e)? extfilter}) {
    if (extfilter != null) {
      return Stream.fromFutures(loaded
          .where((element) => element.enabled)
          .where((element) => extfilter(element))
          .map((e) => e.browse(page, sort)));
    }
    return Stream.fromFutures(loaded
        .where((element) => element.enabled)
        .map((e) => e.browse(page, sort)));
  }

  Stream<List<Entry>> search(int page, String filter,{bool Function(Extension e)? extfilter}) {
    if (extfilter != null) {
      return Stream.fromFutures(loaded
          .where((element) => element.enabled)
          .where((element) => extfilter(element))
          .map((e) => e.search(page, filter)));
    }
    return Stream.fromFutures(loaded
        .where((element) => element.enabled)
        .map((e) => e.search(page, filter)));
  }

  Extension? searchExtension(Entry e) {
    return loaded
        .where((element) => element.enabled)
        .firstWhereOrNull((element) => element.entrycompat(e));
  }

  Extension? searchExtensionbyname(String e) {
    return loaded
        .where((element) => element.enabled)
        .firstWhereOrNull((element) => element.keycompat(e));
  }

  factory ExtensionManager() {
    return _instance;
  }

  Future<void> installlocal(String path) async {
    File f = File(path);
    if (await f.exists() && f.getExtension() == ".dion.js") {
      await installString(await f.readAsString());
    }
  }

  Future<void> installString(String src) async {
    dynamic data = json.decode(src.split("\n")[0].substring(2));
    File newf = (await getPath("extension")).getFile("${data["name"]}.dion.js");
    await newf.writeAsString(src);
    await reload();
  }
}
