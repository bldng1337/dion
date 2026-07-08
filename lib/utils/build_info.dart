class BuildInfo {
  const BuildInfo._();

  static const String version = String.fromEnvironment('BUILD_VERSION');
  static const String commit = String.fromEnvironment('BUILD_COMMIT');
  static const String channel = String.fromEnvironment('BUILD_CHANNEL');

  static bool get isNightly => channel == 'nightly';

  static bool get hasInfo => version.isNotEmpty;
}
