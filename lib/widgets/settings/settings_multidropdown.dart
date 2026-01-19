import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';

class SettingsMultiDropdown<T extends Object> extends StatefulWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<List<T>, dynamic> setting;
  const SettingsMultiDropdown({
    super.key,
    required this.setting,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  State<SettingsMultiDropdown<T>> createState() =>
      _SettingsMultiDropdownState<T>();
}

class _SettingsMultiDropdownState<T extends Object>
    extends State<SettingsMultiDropdown<T>> {
  late MultiDropdownController<T> controller;

  @override
  void initState() {
    super.initState();
    controller = MultiDropdownController<T>();
    _initializeController();
  }

  void _initializeController() {
    final metadata = widget.setting.metadata as EnumMetaData<T>;
    final items = metadata.values
        .map((e) => MultiDropdownItem<T>(label: e.name, value: e.value))
        .toList();
    controller.setItems(
      items.map((item) {
        item.selected = widget.setting.value.contains(item.value);
        return item;
      }),
    );
  }

  @override
  void didUpdateWidget(SettingsMultiDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting != widget.setting) {
      _initializeController();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tile = ListenableBuilder(
      listenable: widget.setting,
      builder: (context, child) => SettingTileWrapper(
        child: DionListTile(
          leading: widget.icon != null ? Icon(widget.icon) : null,
          trailing: DionMultiDropdown<T>(
            defaultItem: const Text('Select'),
            onSelectionChange: (values) {
              widget.setting.value = values;
            },
            controller: controller,
          ),
          title: Text(widget.title, style: context.titleMedium),
        ),
      ),
    );

    if (widget.description != null) {
      return tile.withTooltip(widget.description!);
    }
    return tile;
  }
}
