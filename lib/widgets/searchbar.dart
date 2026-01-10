import 'package:awesome_extensions/awesome_extensions.dart';
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
  final List<Widget>? actions;

  const DionSearchbar({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.hintStyle,
    this.keyboardType,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => SearchBar(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
              color: context.theme.colorScheme.onSurface.withValues(
                alpha: 0.15,
              ),
              width: 0.3,
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.all(
          context.theme.colorScheme.surface,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return context.theme.colorScheme.primary.withValues(alpha: 0.05);
          }
          return Colors.transparent;
        }),
        elevation: WidgetStateProperty.all(0.1),
        controller: controller,
        hintText: hintText,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textStyle: style,
        hintStyle: hintStyle,
        keyboardType: keyboardType,
        trailing: actions,
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
