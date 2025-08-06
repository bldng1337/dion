import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:flutter/material.dart';

class SettingTextbox extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<String, dynamic> setting;
  const SettingTextbox({
    super.key,
    required this.title,
    this.description,
    this.icon,
    required this.setting,
  });

  @override
  Widget build(BuildContext context) {
    final value = setting.value;
    final controller = TextEditingController(text: value);
    final tile = DionListTile(
      leading: icon != null ? Icon(icon) : null,
      subtitle: ListenableBuilder(
        listenable: setting,
        builder: (context, child) => ListenableBuilder(
          listenable: setting,
          builder: (context, child) => DionTextbox(
            controller: controller,
            onSubmitted: (value) => setting.value = value,
            onTapOutside: (_) => setting.value = controller.text,
            maxLines: 1,
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
