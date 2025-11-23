import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';

class SettingTextbox extends StatefulWidget {
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
  State<SettingTextbox> createState() => _SettingTextboxState();
}

class _SettingTextboxState extends State<SettingTextbox> {
  late final TextEditingController _controller;
  late final VoidCallback _settingListener;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value);
    _settingListener = () {
      if (!mounted) return;
      final newText = widget.setting.value;
      if (_controller.text != newText) {
        _controller.value = _controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    };
    widget.setting.addListener(_settingListener);
  }

  @override
  void didUpdateWidget(covariant SettingTextbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting != widget.setting) {
      oldWidget.setting.removeListener(_settingListener);
      _controller.text = widget.setting.value;
      widget.setting.addListener(_settingListener);
    }
  }

  @override
  void dispose() {
    widget.setting.removeListener(_settingListener);
    _controller.dispose();
    super.dispose();
  }

  void _applyControllerToSetting() {
    final text = _controller.text;
    if (text != widget.setting.value) {
      widget.setting.value = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tile = SettingTileWrapper(
      child: DionListTile(
        leading: widget.icon != null ? Icon(widget.icon) : null,
        subtitle: DionTextbox(
          controller: _controller,
          onSubmitted: (_) => _applyControllerToSetting(),
          onTapOutside: (_) => _applyControllerToSetting(),
          maxLines: 1,
        ),
        title: Text(widget.title, style: context.titleMedium),
      ),
    );

    if (widget.description != null) {
      return tile.withTooltip(widget.description!);
    }
    return tile;
  }
}
