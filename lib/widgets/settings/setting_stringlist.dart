import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/immutable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:flutter/material.dart';

/// A string list setting with the new clean design.
///
/// Allows adding and removing string entries.
class SettingStringList extends StatefulWidget {
  final Setting<List<String>, dynamic> setting;
  final String? title;

  const SettingStringList({super.key, required this.setting, this.title});

  @override
  State<SettingStringList> createState() => _SettingStringListState();
}

class _SettingStringListState extends State<SettingStringList> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addEntryFromController() {
    final raw = _controller.text;
    final entry = raw.trim();
    if (entry.isEmpty) return;
    widget.setting.value = widget.setting.value.withNewEntries([entry]);
    _controller.clear();
  }

  void _removeIndex(int index) {
    widget.setting.value = widget.setting.value.withoutIndex([index]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.setting,
      builder: (context, child) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title if provided
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: DionTypography.titleSmall(context.textPrimary),
              ),
              const SizedBox(height: DionSpacing.md),
            ],

            // Empty state
            if (widget.setting.value.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: DionSpacing.lg),
                alignment: Alignment.center,
                child: Text(
                  'No entries',
                  style: DionTypography.bodySmall(context.textTertiary),
                ),
              ),

            // List of entries
            ...widget.setting.value.indexed.map(
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
                      child: Text(
                        e.$2,
                        style: DionTypography.bodyMedium(context.textPrimary),
                      ),
                    ),
                    const SizedBox(width: DionSpacing.sm),
                    DionIconbutton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: context.textTertiary,
                      ),
                      onPressed: () => _removeIndex(e.$1),
                    ),
                  ],
                ),
              ),
            ),

            // Add new entry row
            const SizedBox(height: DionSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DionTextbox(
                    controller: _controller,
                    onSubmitted: (_) => _addEntryFromController(),
                    maxLines: 1,
                    hintText: 'Add new entry...',
                  ),
                ),
                const SizedBox(width: DionSpacing.sm),
                DionIconbutton(
                  icon: Icon(Icons.add, color: DionColors.primary),
                  onPressed: _addEntryFromController,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
