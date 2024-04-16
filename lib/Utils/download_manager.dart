import 'package:background_downloader/background_downloader.dart';
import 'package:dionysos/Entry.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  
  factory NetworkManager() {
    return _instance;
  }
  
  NetworkManager._internal() {

  }

  downloadEpisode(Episode e, EntrySaved saved){
    

  }

  
}
