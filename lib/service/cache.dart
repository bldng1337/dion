import 'package:dionysos/service/network.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:rhttp/rhttp.dart';

class ImgCache extends CacheManager with ImageCacheManager {
  ImgCache(super.config);
}

class CacheService {
  final ImgCache imgcache;
  const CacheService(this.imgcache);

  static Future<void> ensureInitialized() async {
    await locateAsync<NetworkService>();
    final imgcache = ImgCache(
      Config(
        'imgcache',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 50,
        repo: JsonCacheInfoRepository(
          databaseName: 'imgcache',
        ), //TODO: Save this in the database
        fileSystem: IOFileSystem('imgcache'),
        fileService: HttpFileService(
          httpClient: await RhttpCompatibleClient.create(),
        ),
      ),
    );
    logger.i('CacheService initialized');
    register<CacheService>(CacheService(imgcache));
  }
}
