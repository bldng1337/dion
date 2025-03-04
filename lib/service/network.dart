import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart';

abstract class NetworkService {
  RhttpClient get client;

  static Future<void> ensureInitialized() async {
    await Rhttp.init();
    register<NetworkService>(NetworkServiceImpl(await RhttpClient.create()));
  }
}

class NetworkServiceImpl extends NetworkService {
  @override
  final RhttpClient client;
  NetworkServiceImpl(this.client);
}
