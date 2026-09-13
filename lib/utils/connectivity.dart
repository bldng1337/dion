import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dionysos/utils/log.dart';

enum NetworkClass { none, metered, unmetered }

Future<NetworkClass> networkClass() async {
  try {
    final results = await Connectivity().checkConnectivity();
    if (!results.hasConnectivity) return NetworkClass.none;
    return _isUnmetered(results)
        ? NetworkClass.unmetered
        : NetworkClass.metered;
  } catch (e, stack) {
    logger.e('Connectivity check failed', error: e, stackTrace: stack);
    // Let the caller try and fail on its own rather than block.
    return NetworkClass.unmetered;
  }
}

// connectivity_plus reports interface kinds but not the OS metered flag
// (Android can mark individual Wi-Fi networks metered), so this is a
// best-effort classification. WorkManager sees the real flag natively and
// should stay the authority for its own jobs.
bool _isUnmetered(List<ConnectivityResult> results) {
  // A VPN inherits the metering of the interface it rides on, so a VPN
  // listed alongside a metered interface stays metered.
  final metered = results.any(
    (r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.satellite ||
        r == ConnectivityResult.bluetooth ||
        // Unknown interface: treat as metered; skipping a run is cheaper
        // than spending the user's data.
        r == ConnectivityResult.other,
  );
  if (metered) return false;
  return results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn,
  );
}
