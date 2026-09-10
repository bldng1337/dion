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
