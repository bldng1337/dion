import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// Whether the UI runs on a phone-class touch platform, where popups and
/// menus are shown as bottom drawers instead of anchored overlays.
bool get isMobilePlatform => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => true,
  _ => false,
};

class DionDrawerItem {
  final Widget label;
  final IconData? icon;
  final Future<void> Function()? onTap;
  final bool isDestructive;

  /// Section header rendered above this item, grouping related actions.
  final String? section;

  const DionDrawerItem({
    required this.label,
    this.icon,
    this.onTap,
    this.isDestructive = false,
    this.section,
  });
}

/// Body of a bottom drawer: drag handle, optional header row, content.
///
/// [child] is constrained but not wrapped; content that can outgrow the
/// available height must scroll on its own.
class DionDrawer extends StatelessWidget {
  const DionDrawer({super.key, required this.child, this.title, this.trailing});

  final Widget? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || trailing != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(
              top: DionSpacing.md,
              bottom: DionSpacing.sm,
            ),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(DionRadius.xl),
            ),
          ),
        ),
        if (hasHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DionSpacing.lg,
              DionSpacing.xs,
              DionSpacing.md,
              DionSpacing.md,
            ),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: DefaultTextStyle(
                      style: DionTypography.titleMedium(context.textPrimary),
                      child: title!,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Container(
            height: 0.5,
            color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ],
        Flexible(child: child),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

/// Scrollable list of [DionDrawerItem] rows for use inside a [DionDrawer].
class DionDrawerMenu extends StatelessWidget {
  const DionDrawerMenu({
    super.key,
    required this.items,
    this.closeOnTap = true,
    this.maxHeightFactor = 0.7,
  });

  final List<DionDrawerItem> items;

  /// Whether tapping an item closes the surrounding drawer. Persistent
  /// selection drawers keep it open so follow-up actions stay reachable.
  final bool closeOnTap;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: DionSpacing.sm),
        children: [
          for (final item in items) ...[
            if (item.section != null)
              _DionDrawerSectionHeader(section: item.section!),
            _DionDrawerMenuRow(item: item, closeOnTap: closeOnTap),
          ],
        ],
      ),
    );
  }
}

class _DionDrawerSectionHeader extends StatelessWidget {
  const _DionDrawerSectionHeader({required this.section});

  final String section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DionSpacing.xl,
        DionSpacing.md,
        DionSpacing.lg,
        DionSpacing.xs,
      ),
      child: Text(
        section.toUpperCase(),
        style: DionTypography.sectionHeader(context.textTertiary),
      ),
    );
  }
}

class _DionDrawerMenuRow extends StatelessWidget {
  const _DionDrawerMenuRow({required this.item, required this.closeOnTap});

  final DionDrawerItem item;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null;
    final labelColor = !enabled
        ? context.theme.disabledColor
        : item.isDestructive
        ? context.theme.colorScheme.error
        : context.textPrimary;
    final iconColor = !enabled
        ? context.theme.disabledColor
        : item.isDestructive
        ? context.theme.colorScheme.error
        : context.textSecondary;
    return InkWell(
      onTap: enabled
          ? () {
              if (closeOnTap) Navigator.of(context).pop();
              item.onTap!();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Row(
          children: [
            if (item.icon != null)
              Icon(
                item.icon,
                size: 20,
                color: iconColor,
              ).paddingOnly(right: DionSpacing.md),
            Expanded(
              child: DefaultTextStyle(
                style: DionTypography.bodyLarge(labelColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: item.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a modal bottom drawer with the shared handle and header chrome.
Future<T?> showDionDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Widget? title,
  Widget? trailing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => DionDrawer(
      title: title,
      trailing: trailing,
      child: builder(sheetContext),
    ),
  );
}

/// Opens [items] as a vertical action menu in a modal bottom drawer.
Future<void> showDionMenuDrawer({
  required BuildContext context,
  required List<DionDrawerItem> items,
  Widget? title,
}) {
  return showDionDrawer(
    context: context,
    title: title,
    builder: (sheetContext) => DionDrawerMenu(items: items),
  );
}

/// Panel-style popup: a centered [DionDialog] on desktop, a bottom drawer on
/// mobile. [builder] returns the panel content; the dialog chrome is added
/// only on desktop. The content must be able to scroll on its own.
Future<T?> showDionPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (isMobilePlatform) {
    return showDionDrawer(context: context, builder: builder);
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => DionDialog(child: builder(dialogContext)),
  );
}
