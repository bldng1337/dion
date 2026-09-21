import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

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

/// A number input setting with the new clean design.
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

class _SettingNumberboxState<T extends num> extends State<SettingNumberbox<T>>
    with StateDisposeScopeMixin {
  late final TextEditingController _controller = TextEditingController(
    text: widget.setting.value.toString(),
  )..disposedBy(scope);
  late final Observer _settingObserver = Observer(
    _syncFromSetting,
    widget.setting,
    callOnInit: false,
    callIndirectly: false,
  )..disposedBy(scope);

  void _syncFromSetting() {
    final text = widget.setting.value.toString();
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void didUpdateWidget(covariant SettingNumberbox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting != widget.setting) {
      _settingObserver.swapListener(widget.setting);
      _controller.text = widget.setting.value.toString();
    }
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
    final tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: context.textSecondary),
                const SizedBox(width: DionSpacing.md),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
              ),
            ],
          ),

          // Number input
          const SizedBox(height: DionSpacing.sm),
          DionTextbox(
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
        ],
      ),
    );

    if (widget.description != null) {
      return Tooltip(message: widget.description, child: tile);
    }
    return tile;
  }
}
