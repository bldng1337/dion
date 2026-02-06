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
