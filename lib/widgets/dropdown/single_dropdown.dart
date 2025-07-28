import 'package:flutter/material.dart';

class DionDropdownItem<T> {
  final T value;
  final String label;
  const DionDropdownItem({required this.value, required this.label});

  Widget get labelWidget => Text(label);
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
      items: items
          .map((e) => DropdownMenuItem<T>(value: e.value, child: e.labelWidget))
          .toList(),
      onChanged: onChanged,
    );
  }
}
