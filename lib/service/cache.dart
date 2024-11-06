import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:rhttp/rhttp.dart';

class ImgCache extends CacheManager with ImageCacheManager {
  ImgCache(super.config);
}

abstract class CacheService {
  const CacheService();
  ImgCache get imgcache;

  static Future<void> ensureInitialized() async {
    final imgcache = ImgCache(
      Config(
        'imgcache',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 50,
        repo: JsonCacheInfoRepository(databaseName: 'imgcache'),
        fileSystem: IOFileSystem('imgcache'),
        fileService: HttpFileService(
          httpClient: await RhttpCompatibleClient.create(),
        ),
      ),
    );
    logger.i('CacheService initialized');
    register<CacheService>(CacheServiceImpl(imgcache));
  }
}

class CacheServiceImpl extends CacheService {
  @override
  final ImgCache imgcache;
  const CacheServiceImpl(this.imgcache);
}
