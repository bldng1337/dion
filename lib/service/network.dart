import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as runtime;
import 'package:rhttp/rhttp.dart';

/// Turns a `proxy://` URL from an extension into the `http://` URL its
/// runtime proxy serves on in this process; other URLs pass through.
///
/// The proxy binds a random port per start, so stored data keeps the
/// `proxy://` form and every consumer resolves right before loading. Pre-
/// `proxy://` data holds `http://127.0.0.1:<old port>/extproxy/...` URLs,
/// which the runtime re-targets to the current port as well.
String resolveProxyUrl(String url) {
  if (!url.startsWith('proxy:') && !url.startsWith('http://127.0.0.1:')) {
    return url;
  }
  return runtime.resolveProxyUrl(url: url);
}

/// Resolves proxy URLs for every request of an rhttp client; see
/// [resolveProxyUrl].
final proxyUrlInterceptor = SimpleInterceptor(
  beforeRequest: (request) async {
    final url = resolveProxyUrl(request.url);
    return Interceptor.next(
      url == request.url ? request : request.copyWith(url: url),
    );
  },
);

class NetworkService {
  final RhttpClient client;
  NetworkService(this.client);

  static Future<void> ensureInitialized() async {
    await Rhttp.init();
    register<NetworkService>(
      NetworkService(
        await RhttpClient.create(
          settings: const ClientSettings(
            timeoutSettings: TimeoutSettings(
              connectTimeout: Duration(seconds: 20),
            ),
          ),
          interceptors: [proxyUrlInterceptor],
        ),
      ),
    );
  }
}
