import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

extension FileUtils on File {
  File silbling(String name) {
    return File("${parent.absolute.path}/$name");
  }

  String getBasePath() {
    return parent.absolute.path+p.basenameWithoutExtension(path);
  }

  String getExtension() {
    return p.extension(path, 99);
  }

  Future<File> ctwin(String name) {
    return File("${getBasePath()}$name").create(recursive: true);
  }

  File twin(String name) {
    return File("${getBasePath()}$name");
  }
}

extension DirUtils on Directory {
  Future<Directory> sub(String path) async {
    Directory dir = Directory("${absolute.path}/$path/");
    return dir;
  }
  String get name{
    return p.basename(path);
  }

  Future<Directory> csub(String path) async {
    return Directory("${absolute.path}/$path/").create(recursive: true);
  }

  File getFile(String filename) {
    return File("${absolute.path}/$filename");
  }
}

Future<Directory> getPath(String name,{create=true}) async {
  if(create){
    return (await getApplicationDocumentsDirectory()).csub("dion/$name");
  }
  return (await getApplicationDocumentsDirectory()).sub("dion/$name");
}


Future<Directory> getBasePath() async {
  return (await getApplicationDocumentsDirectory()).csub("dion");
}

String utf8toString(Uint8List bytes) {
  return utf8.decode(bytes);
}

String encodeFilename(String s) {
  return Uri.encodeComponent(s)
      .replaceAll(".", "")
      .replaceAll("/", "")
      .replaceAll("%", "")
      .replaceAll(":", "")
      .replaceAll("https", "")
      .replaceAll("http", "");
}

Uint8List stringtoutf8(String text) {
  return utf8.encode(text);
}
