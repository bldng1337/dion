import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/buttons/togglebutton.dart';
import 'package:dionysos/widgets/settings/setting_tile_wrapper.dart';
import 'package:flutter/material.dart';

/// A toggle setting row with a clean, minimal design.
///
/// Displays a title with an optional description tooltip and a toggle switch.
class SettingToggle extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<bool, dynamic> setting;

  const SettingToggle({
    super.key,
    required this.title,
    required this.setting,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final tile = _SettingToggleTile(
          title: title,
          description: description,
          icon: icon,
          value: setting.value,
          onChanged: () => setting.value = !setting.value,
        );

        if (description != null) {
          return Tooltip(message: description, child: tile);
        }
        return tile;
      },
    );
  }
}

class _SettingToggleTile extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final bool value;
  final VoidCallback onChanged;

  const _SettingToggleTile({
    required this.title,
    this.description,
    this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Merge the row into one semantics node so the toggle is announced
    // together with its name (e.g. "Show Title, ..., toggled") instead of
    // the texts floating up into the surrounding section.
    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChanged,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DionSpacing.lg,
              vertical: DionSpacing.md,
            ),
            child: SettingRow(
              icon: icon,
              title: title,
              subtitle: description,
              control: Togglebutton(selected: value, onPressed: onChanged),
            ),
          ),
        ),
      ),
    );
  }
}
