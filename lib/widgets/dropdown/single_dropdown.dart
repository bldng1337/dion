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
  const DionDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'DionDropdown items cannot be empty');
    assert(
      value == null || items.any((item) => item.value == value),
      'Selected value must exist in items list',
    );
    return DropdownButton<T>(
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
          .map((e) => DropdownMenuItem<T>(value: e.value, child: e.labelWidget))
          .toList(),
      onChanged: onChanged,
    );
  }
}
