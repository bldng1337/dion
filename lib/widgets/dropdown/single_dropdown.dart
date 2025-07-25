import 'package:flutter/material.dart';

class DionDropdownItem<T> {
  final T value;
  final String label;
  DionDropdownItem({required this.value, required this.label});

  Widget get widget => Text(label);
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
    return DropdownButton<T>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem<T>(value: e.value, child: e.widget))
          .toList(),
      onChanged: onChanged,
    );
  }
}
