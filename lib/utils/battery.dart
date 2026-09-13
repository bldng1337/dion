import 'package:battery_plus/battery_plus.dart';
import 'package:dionysos/utils/log.dart';

/// Matches Android's BATTERY_STATUS_LOW, the threshold WorkManager uses for its batteryNotLow constraint, so both enforcement paths agree.
const _lowBatteryPercent = 15;

Future<bool> isPluggedIn() async {
  try {
    switch (await Battery().batteryState) {
      case BatteryState.charging:
      case BatteryState.full:
      case BatteryState.connectedNotCharging:
        return true;
      case BatteryState.discharging:
        return false;
      case BatteryState.unknown:
        // Devices without a battery (desktops) report unknown; they run
        // on external power.
        return await batteryLevel() == null;
    }
  } catch (e, stack) {
    logger.e('Battery state check failed', error: e, stackTrace: stack);
    // Never leave background work permanently blocked by a broken sensor.
    return true;
  }
}

/// null when the device has no battery (desktops) or the level is unreadable.
Future<int?> batteryLevel() async {
  try {
    final level = await Battery().batteryLevel;
    // -1 means no battery or unreadable level.
    return level < 0 ? null : level;
  } catch (e, stack) {
    logger.e('Battery level check failed', error: e, stackTrace: stack);
    return null;
  }
}

Future<bool> isBatteryLow() async {
  final level = await batteryLevel();
  return level != null && level <= _lowBatteryPercent;
}
