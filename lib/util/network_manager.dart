import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_isar_store/dio_cache_interceptor_isar_store.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dionysos/util/file_utils.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  late final Dio dio;
  late final CookieJar cookieJar;

  factory NetworkManager() {
    return _instance;
  }
  Future<void> setCache() async {
    final options = CacheOptions(
      store: IsarCacheStore((await getBasePath()).absolute.path),
      hitCacheOnErrorExcept: [401, 403],
      maxStale: const Duration(days: 1),
    );
    dio.interceptors.add(DioCacheInterceptor(options: options));
  }

  NetworkManager._internal() {
    dio = Dio();
    cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
    setCache();
  }

  Future<void> setCookiefromHeader(String header, String url) async {
    await cookieJar
        .saveFromResponse(Uri.parse(url), [Cookie.fromSetCookieValue(header)]);
  }

  Future<List<Cookie>> getCookies(String url) async {
    return cookieJar.loadForRequest(Uri.parse(url));
  }

  Future<void> clearSiteCookies(String url) async {
    await cookieJar.delete(Uri.parse(url));
  }
}
