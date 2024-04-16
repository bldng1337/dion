import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';


class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  late final Dio dio;
  late final CookieJar cookieJar;
  
  factory NetworkManager() {
    return _instance;
  }
  
  NetworkManager._internal() {
    dio=Dio();
    cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  void setCookiefromHeader(String header,String url) async {
    await cookieJar.saveFromResponse(Uri.parse(url), [Cookie.fromSetCookieValue(header)]);
  }

  Future<List<Cookie>> getCookies(String url) async {
    return cookieJar.loadForRequest(Uri.parse(url));
  }

  clearSiteCookies(String url) async {
    await cookieJar.delete(Uri.parse(url));
  }
}
