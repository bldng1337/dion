import 'dart:convert';

import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/internetfile.dart';
import 'package:dionysos/utils/service.dart';
import 'package:inline_result/inline_result.dart';
import 'package:pub_semver/pub_semver.dart';

class RepoExtension {
  final ExtensionData data;
  final String path;

  const RepoExtension(this.data, this.path);

  Version get version => Version.parse(data.version ?? '0.0.0');

  Extension? get installed =>
      locate<SourceExtension>().tryGetExtension(data.id);

  bool get isinstalled => installed != null;

  Future<void> install({Function(double)? onProgress}) async {
    final extension = locate<SourceExtension>();
    final dir = await locateAsync<DirectoryProvider>();
    final file = dir.extensionpath.getFile('${data.id}.dion.js');
    if (await file.exists()) await file.delete();
    await InternetFile.streamToFile(path, file, onReceiveProgress: onProgress);
    await extension.reload();
  }

  factory RepoExtension.fromJson(Map<String, dynamic> json) {
    return RepoExtension(
      ExtensionData.fromJson(json['extdata'] as Map<String, dynamic>),
      json['path'] as String,
    );
  }
}

String resolveRepoURL(String repourl) {
  if (repourl.endsWith('index.repo.json')) {
    return repourl;
  }
  var url = repourl;
  if (url.endsWith('.git')) {
    url = url.substring(0, url.lastIndexOf('.git'));
  }
  if (url.contains('github.com')) {
    return '$url/releases/download/extensions/index.repo.json';
  }
  return '$url/index.repo.json';
}

String resolveExtensionPath(String path, String repourl) {
  if (path.startsWith('http')) {
    return path;
  }
  final url = resolveRepoURL(repourl);
  return '${url.substring(0, url.lastIndexOf('/'))}/$path';
}

class ExtensionRepo {
  final String name;
  final String id;
  final String repourl;
  final String? desc;
  final String? icon;
  final List<RepoExtension> extensions;
  const ExtensionRepo({
    required this.extensions,
    required this.name,
    required this.id,
    required this.repourl,
    this.desc,
    this.icon,
  });

  factory ExtensionRepo.fromJson(Map<String, dynamic> json) {
    assert(json['repo_index_version'] == 1);
    return ExtensionRepo(
      extensions: (json['extensions'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((a) {
            a['path'] = resolveExtensionPath(
              a['path'] as String,
              json['repourl'] as String,
            );
            return a;
          })
          .map(RepoExtension.fromJson)
          .toList(),
      name: json['name'] as String,
      id: json['id'] as String,
      repourl: json['repourl'] as String,
      desc: json['description'] as String?,
      icon: json['icon'] as String?,
    );
  }

  static Future<ExtensionRepo> rawRequest(String url) async {
    final network = locate<NetworkService>();
    final resp = await network.client.get(resolveRepoURL(url));
    final data = json.decode(resp.body);
    return ExtensionRepo.fromJson(data as Map<String, dynamic>);
  }

  static Future<ExtensionRepo> fromURL(String url) async {
    final cache = locate<CacheService>();
    final cached = await cache.repocache.get(url);
    return cached.getOrThrow;
  }
}
