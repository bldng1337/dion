import 'package:dionysos/data/settings/binding.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/settings/binding_capture.dart';
import 'package:flutter/material.dart';

class SettingBindings extends StatelessWidget {
  final String title;
  final String? description;
  final IconData? icon;
  final Setting<List<InputBinding>, dynamic> setting;

  final List<InputBinding> Function()? conflictingBindings;

  const SettingBindings({
    super.key,
    required this.title,
    required this.setting,
    this.description,
    this.icon,
    this.conflictingBindings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, child) {
        final values = setting.value;
        final tile = _SettingBindingsTile(
          title: title,
          icon: icon,
          bindings: values,
          onRemove: (i) {
            final next = List<InputBinding>.from(values)..removeAt(i);
            setting.value = next;
          },
          onAdd: () async {
            final captured = await showBindingCapture(context);
            if (captured == null) return;
            if (values.any((b) => b.identifier == captured.identifier)) {
              return; // already bound to this action — ignore
            }
            setting.value = [...values, captured];
          },
        );
        if (description != null) {
          return Tooltip(message: description, child: tile);
        }
        return tile;
      },
    );
  }
}

class _SettingBindingsTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<InputBinding> bindings;
  final ValueChanged<int> onRemove;
  final Future<void> Function() onAdd;

  const _SettingBindingsTile({
    required this.title,
    required this.bindings,
    required this.onRemove,
    required this.onAdd,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: context.textSecondary),
                const SizedBox(width: DionSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: DionTypography.titleSmall(context.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: 'Add binding',
                visualDensity: VisualDensity.compact,
                onPressed: onAdd,
              ),
            ],
          ),
          const SizedBox(height: DionSpacing.sm),
          if (bindings.isEmpty)
            Text(
              'No bindings yet',
              style: DionTypography.bodySmall(context.textTertiary),
            )
          else
            Wrap(
              spacing: DionSpacing.sm,
              runSpacing: DionSpacing.sm,
              children: [
                for (var i = 0; i < bindings.length; i++)
                  _BindingChip(
                    label: bindings[i].label,
                    onRemove: () => onRemove(i),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BindingChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _BindingChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.sm,
        vertical: DionSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: DionColors.primary.withValues(alpha: 0.1),
        borderRadius: DionRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: DionTypography.labelMedium(DionColors.primary)),
          const SizedBox(width: DionSpacing.xs),
          InkWell(
            onTap: onRemove,
            borderRadius: DionRadius.small,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 14,
                color: DionColors.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
