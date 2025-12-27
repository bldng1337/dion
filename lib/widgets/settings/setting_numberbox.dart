import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SinglePeriodEnforcer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if ('.'.allMatches(newText).length <= 1) {
      return newValue;
    }
    return oldValue;
  }
}

class SettingNumberbox<T extends num> extends StatefulWidget {
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

  @override
  State<SettingNumberbox<T>> createState() => _SettingNumberboxState<T>();
}

class _SettingNumberboxState<T extends num> extends State<SettingNumberbox<T>> {
  late final TextEditingController _controller;
  late VoidCallback _settingListener;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.setting.value.toString());

    _settingListener = () {
      if (!mounted) return;
      final text = widget.setting.value.toString();
      if (_controller.text != text) {
        _controller.text = text;
      }
    };
    widget.setting.addListener(_settingListener);
  }

  @override
  void didUpdateWidget(covariant SettingNumberbox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting != widget.setting) {
      oldWidget.setting.removeListener(_settingListener);
      _controller.text = widget.setting.value.toString();
      widget.setting.addListener(_settingListener);
    }
  }

  @override
  void dispose() {
    widget.setting.removeListener(_settingListener);
    _controller.dispose();
    super.dispose();
  }

  T _convert(num value) {
    if (T == int) return value.toInt() as T;
    if (T == double) return value.toDouble() as T;
    throw UnimplementedError('Unsupported numeric type $T');
  }

  void _applyControllerValueToSetting() {
    final text = _controller.text;
    final parsed = num.tryParse(text);
    if (parsed == null) return;
    widget.setting.value = _convert(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final tile = SettingTileWrapper(
      child: DionListTile(
        leading: widget.icon != null ? Icon(widget.icon) : null,
        subtitle: DionTextbox(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            SinglePeriodEnforcer(),
            FilteringTextInputFormatter.allow(RegExp(r'[\d\.]')),
          ],
          onSubmitted: (_) => _applyControllerValueToSetting(),
          onTapOutside: (_) => _applyControllerValueToSetting(),
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
