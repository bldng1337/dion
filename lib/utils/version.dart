import 'package:pub_semver/pub_semver.dart';

Version parseVersion(String version) {
  final parts = version.split('+');
  final core = parts[0].split('.');
  while (core.length < 3) {
    core.add('0');
  }
  final normalized =
      '${core.join('.')}${parts.length > 1 ? '+${parts.sublist(1).join('+')}' : ''}';
  return Version.parse(normalized);
}
