import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/text_replacement.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/dialog/text_replacement.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/selection.dart';
import 'package:flutter/material.dart';

class SettingReplaceList extends StatelessWidget {
  final Setting<List<TextReplacement>, dynamic> setting;
  final String? title;

  const SettingReplaceList({super.key, required this.setting, this.title});

  Future<void> _add(BuildContext context) async {
    final rule = await showReplacementEditor(context);
    if (rule == null) return;
    setting.value = [...setting.value, rule];
  }

  Future<void> _edit(BuildContext context, int index) async {
    final rule = await showReplacementEditor(
      context,
      find: setting.value[index].find,
      replaceWith: setting.value[index].replaceWith,
    );
    if (rule == null) return;
    final updated = [...setting.value];
    updated[index] = rule;
    setting.value = updated;
  }

  void _remove(int index) {
    setting.value = [
      ...setting.value.sublist(0, index),
      ...setting.value.sublist(index + 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: setting,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: DionTypography.titleSmall(context.textPrimary),
              ),
              const SizedBox(height: DionSpacing.md),
            ],
            if (setting.value.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: DionSpacing.lg),
                alignment: Alignment.center,
                child: Text(
                  'No replacements',
                  style: DionTypography.bodySmall(context.textTertiary),
                ),
              ),
            ...setting.value.indexed.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: DionSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: DionSpacing.md,
                  vertical: DionSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceMuted.withValues(alpha: 0.5),
                  borderRadius: DionRadius.small,
                  border: Border.all(
                    color: context.borderColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Selection(
                        child: Text.rich(
                          TextSpan(
                            text: e.$2.find,
                            style: DionTypography.bodyMedium(
                              context.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: e.$2.isStripping
                                    ? '  (removed)'
                                    : '  →  ${e.$2.replaceWith}',
                                style: DionTypography.bodyMedium(
                                  context.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: DionSpacing.sm),
                    DionIconbutton(
                      tooltip: 'Edit Replacement',
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: context.textTertiary,
                      ),
                      onPressed: () => _edit(context, e.$1),
                    ),
                    DionIconbutton(
                      tooltip: 'Remove Replacement',
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: context.textTertiary,
                      ),
                      onPressed: () => _remove(e.$1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DionSpacing.sm),
            DionTextbutton(
              type: ButtonType.elevated,
              onPressed: () => _add(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: DionSpacing.xs),
                  Text('Add Replacement'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
