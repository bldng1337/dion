import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart';

class InternetFile {
  static Future<Uint8List> download(
    String url, {
    Map<String, String>? query,
    HttpHeaders? headers,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final network = locate<NetworkService>();
    final res = await network.client.getBytes(
      url,
      query: query,
      headers: headers,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return res.body;
  }

  static Future<void> save(
    String url,
    File file, {
    Map<String, String>? query,
    HttpHeaders? headers,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    //TODO: Stream to file
    final network = locate<NetworkService>();
    final res = await network.client.getBytes(
      url,
      query: query,
      headers: headers,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    await file.writeAsBytes(res.body);
  }
}
