import 'package:dionysos/service/extension.dart';

extension ReleaseStatusExt on ReleaseStatus {
  String asString() => switch (this) {
    ReleaseStatus.complete => 'Complete',
    ReleaseStatus.releasing => 'Releasing',
    ReleaseStatus.unknown => 'Unknown',
  };
}

extension StringExt on String {
  String get humanized {
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      final ch = this[i];
      if (ch.toUpperCase() == ch &&
          ch.toLowerCase() != ch &&
          buf.isNotEmpty) {
        buf.write(' ');
      }
      buf.write(ch);
    }
    final trimmed = buf.toString().trim();
    if (trimmed.isEmpty) return this;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
