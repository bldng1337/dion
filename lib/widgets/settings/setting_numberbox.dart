import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SinglePeriodEnforcer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    // Allow only one period
    if ('.'.allMatches(newText).length <= 1) {
      return newValue;
    }
    return oldValue;
  }
}

class SettingNumberbox<T extends num> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<T, dynamic> setting;
  const SettingNumberbox({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.setting,
  });

  T convert(num value) => switch (T) {
    int => value.toInt() as T,
    double => value.toDouble() as T,
    _ => throw UnimplementedError(),
  };

  @override
  Widget build(BuildContext context) {
    final value = setting.value;
    final controller = TextEditingController(text: value.toString());
    final tile = DionListTile(
      leading: icon != null ? Icon(icon) : null,
      subtitle: ListenableBuilder(
        listenable: setting,
        builder: (context, child) => ListenableBuilder(
          listenable: setting,
          builder: (context, child) => DionTextbox(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              SinglePeriodEnforcer(),
              FilteringTextInputFormatter.allow(RegExp(r'[\d\.]')),
            ],
            onSubmitted: (value) => setting.value = convert(num.parse(value)),
          ),
        ),
      ),
      title: Text(title, style: context.titleMedium),
    ).paddingAll(5);
    if (description != null) {
      return tile.withTooltip(description!);
    }
    return tile;
  }
}
