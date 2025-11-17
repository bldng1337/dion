import 'package:dionysos/service/source_extension.dart';

extension CustomUIExt on CustomUI? {
  bool get isEmpty {
    if (this == null) return true;
    return switch (this) {
      CustomUI_Column(:final children) => children.isEmpty,
      CustomUI_Row(:final children) => children.isEmpty,
      _ => false,
    };
  }
}
