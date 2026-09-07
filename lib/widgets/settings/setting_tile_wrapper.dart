import 'package:dionysos/utils/design_tokens.dart';
import 'package:flutter/material.dart';

/// A minimal wrapper for setting items that provides consistent spacing
/// without the heavy boxed-in visual treatment.
///
/// Uses bottom dividers instead of full borders for a cleaner,
/// more scannable settings list.
class SettingTileWrapper extends StatelessWidget {
  final Widget child;
  final bool showDivider;
  final EdgeInsets? padding;

  const SettingTileWrapper({
    super.key,
    required this.child,
    this.showDivider = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: DionSpacing.lg,
                vertical: DionSpacing.xs,
              ),
          child: child,
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(
              left: DionSpacing.lg,
              right: DionSpacing.lg,
            ),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: context.dionDivider,
            ),
          ),
      ],
    );
  }
}

/// Lays out a setting's label (icon, title, subtitle) next to its control.
///
/// When the available width is too narrow (phones, dialogs), the control's
/// intrinsic width would squeeze the title into per-character wrapping, so
/// the control is stacked below the label instead.
class SettingRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final Widget control;
  final double compactWidth;

  const SettingRow({
    super.key,
    this.icon,
    required this.title,
    this.titleStyle,
    this.subtitle,
    required this.control,
    this.compactWidth = DionBreakpoints.compact,
  });

  @override
  Widget build(BuildContext context) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: titleStyle ?? DionTypography.titleSmall(context.textPrimary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: DionTypography.bodySmall(context.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final iconPrefix = icon == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: DionSpacing.md),
            child: Icon(icon, size: 20, color: context.textSecondary),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < compactWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (iconPrefix != null) iconPrefix,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    const SizedBox(height: DionSpacing.sm),
                    control,
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            if (iconPrefix != null) iconPrefix,
            Expanded(child: label),
            const SizedBox(width: DionSpacing.md),
            control,
          ],
        );
      },
    );
  }
}

/// A grouped container for settings that visually groups related items
/// with a subtle background and rounded corners.
class SettingGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? margin;

  const SettingGroup({super.key, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: DionSpacing.md,
            vertical: DionSpacing.sm,
          ),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: DionRadius.medium,
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.5),
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
      // Wrap each child to remove its own divider/padding if it's a SettingTileWrapper
      result.add(children[i]);
    }
    return result;
  }
}
