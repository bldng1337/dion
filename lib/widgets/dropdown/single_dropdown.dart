import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:flutter/material.dart';

class DionDropdownItem<T> {
  final T value;
  final String label;
  const DionDropdownItem({required this.value, required this.label});

  Widget get labelWidget => Text(label);
  Widget? get selectedItemWidget => null;
}

class DionDropdownItemWidget<T> extends DionDropdownItem<T> {
  @override
  final Widget labelWidget;
  @override
  final Widget? selectedItemWidget;

  const DionDropdownItemWidget({
    required super.value,
    required super.label,
    required this.labelWidget,
    this.selectedItemWidget,
  });
}

class DionDropdown<T> extends StatelessWidget {
  final List<DionDropdownItem<T>> items;
  final T? value;
  final void Function(T?)? onChanged;

  /// Fill the available width instead of sizing to the widest menu item.
  /// Without it DropdownButton measures every item at unbounded width, so a
  /// long label overflows narrow containers (rows, dialogs).
  /// Must stay off in intrinsically-sized contexts (Wrap, unbounded rows).
  final bool isExpanded;
  const DionDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'DionDropdown items cannot be empty');
    assert(
      value == null || items.any((item) => item.value == value),
      'Selected value must exist in items list',
    );
    if (isMobilePlatform) {
      return _DionDropdownTrigger<T>(
        items: items,
        value: value,
        onChanged: onChanged,
        isExpanded: isExpanded,
      );
    }
    return DropdownButton<T>(
      isExpanded: isExpanded,
      value: value,
      selectedItemBuilder: (context) {
        return items.map((e) {
          return e.selectedItemWidget ??
              Container(
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 100),
                child: e.labelWidget,
              );
        }).toList();
      },
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e.value,
              // Mark the currently selected entry so screen readers announce
              // which menu item is active.
              child: e.value == value
                  ? Semantics(selected: true, child: e.labelWidget)
                  : e.labelWidget,
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Phone trigger that mirrors the DropdownButton look (selected label, drop
/// arrow, underline) but opens a bottom drawer instead of an anchored menu.
class _DionDropdownTrigger<T> extends StatelessWidget {
  const _DionDropdownTrigger({
    required this.items,
    required this.value,
    required this.onChanged,
    required this.isExpanded,
  });

  final List<DionDropdownItem<T>> items;
  final T? value;
  final void Function(T?)? onChanged;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final selected = items.where((e) => e.value == value).toList();
    final Widget? selectedWidget = selected.isEmpty
        ? null
        : selected.first.selectedItemWidget ??
              Container(
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 100),
                child: selected.first.labelWidget,
              );
    return InkWell(
      borderRadius: BorderRadius.circular(DionRadius.xs),
      onTap: enabled
          ? () {
              showDionDrawer(
                context: context,
                builder: (sheetContext) => _DionDropdownSheet<T>(
                  items: items,
                  value: value,
                  onSelect: (v) {
                    Navigator.of(sheetContext).pop();
                    onChanged?.call(v);
                  },
                ),
              );
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DionSpacing.xs),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (selectedWidget != null)
                  if (isExpanded)
                    Expanded(child: selectedWidget)
                  else
                    Flexible(child: selectedWidget),
                Icon(
                  Icons.arrow_drop_down,
                  color: enabled ? null : context.theme.disabledColor,
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: enabled
                ? context.theme.dividerColor
                : context.theme.disabledColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class _DionDropdownSheet<T> extends StatelessWidget {
  const _DionDropdownSheet({
    required this.items,
    required this.value,
    required this.onSelect,
  });

  final List<DionDropdownItem<T>> items;
  final T? value;
  final void Function(T) onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: DionSpacing.sm),
        children: [
          for (final item in items)
            _DionDropdownSheetRow(
              item: item,
              selected: item.value == value,
              onSelect: () => onSelect(item.value),
            ),
        ],
      ),
    );
  }
}

class _DionDropdownSheetRow<T> extends StatelessWidget {
  const _DionDropdownSheetRow({
    required this.item,
    required this.selected,
    required this.onSelect,
  });

  final DionDropdownItem<T> item;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onSelect,
        child: ColoredBox(
          color: selected
              ? context.theme.colorScheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DionSpacing.lg,
              vertical: DionSpacing.md,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: context.theme.colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: DionSpacing.md),
                Expanded(
                  child: DefaultTextStyle(
                    style: DionTypography.bodyLarge(
                      selected
                          ? context.theme.colorScheme.primary
                          : context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: item.labelWidget,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
