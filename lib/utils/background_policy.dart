import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/battery.dart';
import 'package:dionysos/utils/connectivity.dart';

/// State of one background condition: off, passing, or blocking deferred
/// work right now.
enum RuleStatus { off, passed, blocked }

/// [BackgroundPolicy.evaluate] result: per-rule status plus the measurements
/// the statuses were derived from, so the settings preview can show why work
/// runs or waits.
class BackgroundEvaluation {
  final RuleStatus unmeteredRule;
  final RuleStatus chargingRule;
  final RuleStatus batteryRule;
  final NetworkClass network;
  final bool pluggedIn;
  final int? batteryLevel;

  const BackgroundEvaluation({
    required this.unmeteredRule,
    required this.chargingRule,
    required this.batteryRule,
    required this.network,
    required this.pluggedIn,
    required this.batteryLevel,
  });

  bool get allowed =>
      unmeteredRule != RuleStatus.blocked &&
      chargingRule != RuleStatus.blocked &&
      batteryRule != RuleStatus.blocked;
}

abstract final class BackgroundPolicy {
  static Future<BackgroundEvaluation> evaluate() async {
    final background = settings.background;
    final network = await networkClass();
    final pluggedIn = await isPluggedIn();
    final level = await batteryLevel();

    RuleStatus rule(bool enabled, bool ok) =>
        !enabled ? RuleStatus.off : (ok ? RuleStatus.passed : RuleStatus.blocked);

    return BackgroundEvaluation(
      unmeteredRule: rule(
        background.unmeteredOnly.value,
        network == NetworkClass.unmetered,
      ),
      chargingRule: rule(background.chargingOnly.value, pluggedIn),
      batteryRule: rule(background.batteryNotLow.value, !await isBatteryLow()),
      network: network,
      pluggedIn: pluggedIn,
      batteryLevel: level,
    );
  }

  static Future<bool> allowsWork() async => (await evaluate()).allowed;
}
