import 'dart:io';

import 'package:share_plus/share_plus.dart';

Future<ShareResult> shareText(String url) {
  return Share.share(url);
}

Future<ShareResult> shareURI(Uri url) {
  return Share.shareUri(url);
}

Future<ShareResult> shareFiles(List<File> files) {
  return Share.shareXFiles(files.map((e) => XFile(e.path)).toList());
}

Future<ShareResult> shareXFiles(List<XFile> files) {
  return Share.shareXFiles(files);
}

extension UriShareExt on Uri {
  Future<ShareResult> share() {
    return shareURI(this);
  }
}

extension IterableShareExt on Iterable<File> {
  Future<ShareResult> share() {
    return shareFiles(toList());
  }
}

extension IterableXFileShareExt on Iterable<XFile> {
  Future<ShareResult> share() {
    return shareXFiles(toList());
  }
}

extension ListShareExt on List<File> {
  Future<ShareResult> share() {
    return shareFiles(this);
  }
}

extension ListXFileShareExt on List<XFile> {
  Future<ShareResult> share() {
    return shareXFiles(this);
  }
}

extension XFileShareExt on XFile {
  Future<ShareResult> share() {
    return shareXFiles([this]);
  }
}

extension FileShareExt on File {
  Future<ShareResult> share() {
    return shareFiles([this]);
  }
}

extension StringShareExt on String {
  Future<ShareResult> share() {
    return shareText(this);
  }
}
