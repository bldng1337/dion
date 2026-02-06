import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:flutter/material.dart';

/// A dropdown setting with a clean, minimal design.
///
/// Shows the title with a dropdown selector on the right.
class SettingDropdown<T> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<T, EnumMetaData<T>> setting;

  const SettingDropdown({
    super.key,
    required this.setting,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final items = setting.metadata.values
        .map((e) => DionDropdownItem<T>(label: e.name, value: e.value))
        .toList();

    // Handle invalid current value
    if (!items.any((item) => item.value == setting.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          setting.value = setting.metadata.values.first.value;
        } catch (_) {}
      });
    }

    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final tile = _SettingDropdownTile<T>(
          title: title,
          description: description,
          icon: icon,
          items: items,
          value: setting.value,
          onChanged: (value) {
            if (value == null) {
              try {
                setting.value = setting.intialValue;
              } catch (_) {}
            } else {
              setting.value = value;
            }
          },
        );

        if (description != null) {
          return Tooltip(message: description!, child: tile);
        }
        return tile;
      },
    );
  }
}

class _SettingDropdownTile<T> extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final List<DionDropdownItem<T>> items;
  final T value;
  final ValueChanged<T?> onChanged;

  const _SettingDropdownTile({
    required this.title,
    this.description,
    this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: context.textSecondary),
            const SizedBox(width: DionSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: DionTypography.bodySmall(context.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: DionSpacing.md),
          DionDropdown<T>(items: items, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
