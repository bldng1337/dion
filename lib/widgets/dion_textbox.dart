import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DionTextbox extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool? autofocus;
  final bool? enabled;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;
  final int? maxLines;
  final int? minLines;
  final TextAlignVertical? textAlignVertical;
  final List<TextInputFormatter>? inputFormatters;
  final bool? obscureText;
  final bool? autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final Iterable<String>? autofillHints;
  final Iterable<String>? restorationId;
  final bool? readOnly;
  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;

  const DionTextbox({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus,
    this.enabled,
    this.keyboardType,
    this.textCapitalization,
    this.maxLines,
    this.minLines,
    this.textAlignVertical,
    this.inputFormatters,
    this.obscureText,
    this.autocorrect,
    this.smartDashesType,
    this.smartQuotesType,
    this.autofillHints,
    this.restorationId,
    this.readOnly,
    this.onTap,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus ?? false,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      maxLines: maxLines,
      minLines: minLines,
      textAlignVertical: textAlignVertical,
      // buildCounter: buildCounter,
      inputFormatters: inputFormatters,
      obscureText: obscureText ?? false,
      autocorrect: autocorrect ?? true,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      autofillHints: autofillHints,
      // restorationId: restorationId,
      readOnly: readOnly ?? false,
      onTap: onTap,
      onTapOutside: onTapOutside,
    );
  }
}
