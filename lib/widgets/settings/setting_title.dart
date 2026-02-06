import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';

/// A section header for settings with an editorial, refined style.
///
/// Uses uppercase text with letter spacing for clear visual hierarchy.
/// Optional children are indented and grouped together.
class SettingTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget>? children;
  final String? subtitle;

  const SettingTitle({
    super.key,
    required this.title,
    this.children,
    this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasChildren = children != null && children!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(
            left: DionSpacing.lg,
            right: DionSpacing.lg,
            top: DionSpacing.xl,
            bottom: DionSpacing.sm,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: context.textTertiary),
                const SizedBox(width: DionSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: DionTypography.sectionHeader(context.textTertiary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: DionTypography.bodySmall(context.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Children in a grouped container
        if (hasChildren) _SettingSection(children: children!),
      ],
    );
  }
}

/// Internal widget that creates a visually grouped section for settings
class _SettingSection extends StatelessWidget {
  final List<Widget> children;

  const _SettingSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DionSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: DionRadius.medium,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildChildrenWithDividers(context),
        ),
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers(BuildContext context) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      // Add divider between items, but not after the last one
      if (i < children.length - 1) {
        result.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DionSpacing.md),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: context.dionDivider.withValues(alpha: 0.7),
            ),
          ),
        );
      }
    }
    return result;
  }
}

/// A standalone setting item without section grouping.
/// Use this for top-level settings that don't belong to a section.
class SettingItem extends StatelessWidget {
  final Widget child;
  final bool showDivider;

  const SettingItem({super.key, required this.child, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DionSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceMuted.withValues(alpha: 0.4),
          borderRadius: DionRadius.medium,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
