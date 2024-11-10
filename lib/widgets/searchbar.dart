import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DionSearchbar extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final WidgetStateProperty<TextStyle?>? style;
  final WidgetStateProperty<TextStyle?>? hintStyle;
  final TextInputType? keyboardType;

  const DionSearchbar(
      {super.key,
      this.controller,
      this.hintText,
      this.onChanged,
      this.onSubmitted,
      this.style,
      this.hintStyle,
      this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => SearchBar(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textStyle: style,
          hintStyle: hintStyle,
          keyboardType: keyboardType,
        ),
      DionThemeMode.cupertino => CupertinoSearchTextField(
        controller: controller,
        placeholder: hintText,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: style?.resolve({WidgetState.focused}),
        placeholderStyle: hintStyle?.resolve({WidgetState.focused}),
        keyboardType: keyboardType,
      ),
    };
  }
}
