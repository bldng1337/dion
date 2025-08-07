import 'package:dionysos/utils/service.dart';
import 'package:rhttp/rhttp.dart';

class NetworkService {
  final RhttpClient client;
  NetworkService(this.client);

  static Future<void> ensureInitialized() async {
    await Rhttp.init();
    register<NetworkService>(NetworkService(await RhttpClient.create()));
  }
}
