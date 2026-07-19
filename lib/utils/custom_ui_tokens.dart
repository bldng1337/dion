import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:flutter/material.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

extension ButtonTypeExt on rust.ButtonType {
  ButtonType get toFlutter => switch (this) {
    rust.ButtonType.elevated => ButtonType.elevated,
    rust.ButtonType.filled => ButtonType.filled,
    rust.ButtonType.ghost => ButtonType.ghost,
  };
}

extension RustColorTokenExt on rust.ColorToken {
  Color resolve(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      rust.ColorToken.primary => cs.primary,
      rust.ColorToken.onPrimary => cs.onPrimary,
      rust.ColorToken.primaryContainer => cs.primaryContainer,
      rust.ColorToken.onPrimaryContainer => cs.onPrimaryContainer,
      rust.ColorToken.secondary => cs.secondary,
      rust.ColorToken.onSecondary => cs.onSecondary,
      rust.ColorToken.surface => cs.surface,
      rust.ColorToken.onSurface => cs.onSurface,
      rust.ColorToken.surfaceContainer => cs.surfaceContainer,
      rust.ColorToken.surfaceContainerHighest => cs.surfaceContainerHighest,
      rust.ColorToken.error => cs.error,
      rust.ColorToken.onError => cs.onError,
      // No dedicated disabled slot in ColorScheme; use the standard 0.38 contrast ratio used by Material for disabled content.
      rust.ColorToken.disabled => cs.onSurface.withValues(alpha: 0.38),
      rust.ColorToken.shadow => cs.shadow,
    };
  }
}

extension NullableRustColorTokenExt on rust.ColorToken? {
  Color? resolve(BuildContext context) => this?.resolve(context);
}

extension RustAlignmentExt on rust.Alignment {
  Alignment get toFlutter => switch (this) {
    rust.Alignment.center => Alignment.center,
    rust.Alignment.topLeft => Alignment.topLeft,
    rust.Alignment.topCenter => Alignment.topCenter,
    rust.Alignment.topRight => Alignment.topRight,
    rust.Alignment.centerLeft => Alignment.centerLeft,
    rust.Alignment.centerRight => Alignment.centerRight,
    rust.Alignment.bottomLeft => Alignment.bottomLeft,
    rust.Alignment.bottomCenter => Alignment.bottomCenter,
    rust.Alignment.bottomRight => Alignment.bottomRight,
  };
}

extension NullableRustAlignmentExt on rust.Alignment? {
  Alignment? get toFlutter => this?.toFlutter;
}

extension RustEdgeInsetsExt on rust.EdgeInsets {
  EdgeInsetsGeometry get toFlutter => EdgeInsetsDirectional.only(
    top: top ?? 0,
    bottom: bottom ?? 0,
    start: left ?? 0,
    end: right ?? 0,
  );
}

extension NullableRustEdgeInsetsExt on rust.EdgeInsets? {
  EdgeInsetsGeometry? get toFlutter => this?.toFlutter;
}

extension RustWrapAlignmentExt on rust.WrapAlignment {
  WrapAlignment get toFlutter => switch (this) {
    rust.WrapAlignment.start => WrapAlignment.start,
    rust.WrapAlignment.center => WrapAlignment.center,
    rust.WrapAlignment.end => WrapAlignment.end,
    rust.WrapAlignment.spaceBetween => WrapAlignment.spaceBetween,
    rust.WrapAlignment.spaceAround => WrapAlignment.spaceAround,
    rust.WrapAlignment.spaceEvenly => WrapAlignment.spaceEvenly,
  };
}

extension NullableRustWrapAlignmentExt on rust.WrapAlignment? {
  WrapAlignment? get toFlutter => this?.toFlutter;
}

extension RustStackFitExt on rust.StackFit {
  StackFit get toFlutter => switch (this) {
    rust.StackFit.loose => StackFit.loose,
    rust.StackFit.expand => StackFit.expand,
    rust.StackFit.passthrough => StackFit.passthrough,
  };
}

extension NullableRustStackFitExt on rust.StackFit? {
  StackFit? get toFlutter => this?.toFlutter;
}

extension RustContainerTypeExt on rust.ContainerType {
  ContainerType get toFlutter => switch (this) {
    rust.ContainerType.ghost => ContainerType.ghost,
    rust.ContainerType.filled => ContainerType.filled,
    rust.ContainerType.outlined => ContainerType.outlined,
  };
}

extension NullableRustContainerTypeExt on rust.ContainerType? {
  ContainerType? get toFlutter => this?.toFlutter;
}

extension RustTextStyleExt on rust.TextStyle {
  TextStyle toFlutter() {
    final decorations = <TextDecoration>[
      if (underline == true) TextDecoration.underline,
      if (strikethrough == true) TextDecoration.lineThrough,
    ];
    return TextStyle(
      fontWeight: bold == true ? FontWeight.bold : null,
      fontStyle: italic == true ? FontStyle.italic : null,
      decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
      fontSize: fontSize?.toDouble(),
      fontFamily: code == true ? 'monospace' : null,
    );
  }
}

extension NullableRustTextStyleExt on rust.TextStyle? {
  TextStyle? toFlutter() => this?.toFlutter();
}
