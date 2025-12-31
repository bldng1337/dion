import 'package:dionysos/service/extension.dart';

extension ReleaseStatusExt on ReleaseStatus {
  String asString() => switch (this) {
    ReleaseStatus.complete => 'Complete',
    ReleaseStatus.releasing => 'Releasing',
    ReleaseStatus.unknown => 'Unknown',
  };
}
