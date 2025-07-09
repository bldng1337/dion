import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:flutter/material.dart';

class MultiDropdownItem<T> {
  final T value;
  final String label;
  bool selected = false;

  MultiDropdownItem({required this.value, required this.label});

  MultiDropdownItem.active({required this.value, required this.label})
      : selected = true;

  Widget get widget => Text(label);
}

class MultiDropdownController<T> extends ChangeNotifier {
  List<MultiDropdownItem<T>> selected = [];

  List<MultiDropdownItem<T>> get items => selected;

  void setItems(Iterable<MultiDropdownItem<T>> items) {
    selected.clear();
    selected.addAll(items);
    notifyListeners();
  }

  void add(MultiDropdownItem<T> item) {
    selected.add(item);
    notifyListeners();
  }

  void addAll(Iterable<MultiDropdownItem<T>> items) {
    selected.addAll(items);
    notifyListeners();
  }

  void removeWhere(bool Function(MultiDropdownItem<T>) test) {
    selected.removeWhere(test);
    notifyListeners();
  }

  void remove(T item) {
    removeWhere((e) => e.value == item);
  }

  void clear() {
    selected.clear();
    notifyListeners();
  }

  void selectIndex(int index) {
    selected[index].selected = true;
    notifyListeners();
  }

  void selectWhere(bool Function(MultiDropdownItem<T>) test) {
    for (final item in selected.where(test)) {
      item.selected = true;
    }
    notifyListeners();
  }

  void deselectWhere(bool Function(MultiDropdownItem<T>) test) {
    for (final item in selected.where(test)) {
      item.selected = false;
    }
    notifyListeners();
  }

  void toggleWhere(bool Function(MultiDropdownItem<T>) test) {
    for (final item in selected.where(test)) {
      item.selected = !item.selected;
    }
    notifyListeners();
  }

  void toggle(T item) {
    final mitem = selected.firstWhere((e) => e.value == item);
    mitem.selected = !mitem.selected;
    notifyListeners();
  }

  void toggleIndex(int index) {
    selected[index].selected = !selected[index].selected;
    notifyListeners();
  }
}

class DionMultiDropdown<T extends Object> extends StatefulWidget {
  final List<MultiDropdownItem<T>>? items;
  final FutureOr<void> Function(List<T>)? onSelectionChange;
  final MultiDropdownController<T>? controller;
  final Widget Function(
    BuildContext context,
    MultiDropdownItem<T> item,
    VoidCallback onTap,
  )? buildItem;

  const DionMultiDropdown({
    super.key,
    this.items,
    this.onSelectionChange,
    this.controller,
    this.buildItem,
  });

  @override
  State<DionMultiDropdown<T>> createState() => _DionMultiDropdownState<T>();
}

class _DionMultiDropdownState<T extends Object>
    extends State<DionMultiDropdown<T>> {
  late MultiDropdownController<T> controller;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      controller = MultiDropdownController<T>();
    } else {
      controller = widget.controller!;
    }
    if (widget.items != null) {
      controller.addAll(widget.items! as Iterable<MultiDropdownItem<T>>);
    }
  }

  Widget _buildItem(
    BuildContext context,
    MultiDropdownItem<T> item,
    VoidCallback onTap,
  ) {
    return MenuItemButton(
      onPressed: onTap,
      style: item.selected
          ? ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                context.theme.primaryColor.lighten(5),
              ),
            )
          : null,
      child: item.widget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.buildItem ?? _buildItem;
    return Loadable(
      loading: const BoundsWidget(
        child: DionTextbutton(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
          ),
        ),
      ).applyShimmer(
        highlightColor: context.backgroundColor.lighten(20),
        baseColor: context.backgroundColor,
      ),
      builder: (context, child, setFuture) => ListenableBuilder(
        listenable: controller,
        builder: (context, child) => MenuAnchor(
          menuChildren: controller.items.indexed
              .map(
                (e) => builder(context, e.$2, () {
                  controller.toggleIndex(e.$1);
                  setFuture(
                    widget.onSelectionChange?.call(
                      controller.selected
                          .where((e) => e.selected)
                          .map((e) => e.value)
                          .toList(),
                    ),
                  );
                }),
              )
              .toList(),
          builder: (context, menucontroller, child) => DionTextbutton(
            child: Row(
              children: controller.items
                  .where((e) => e.selected)
                  .map((e) => e.widget.paddingAll(10))
                  .toList(),
            ),
            onPressed: () {
              if (menucontroller.isOpen) {
                menucontroller.close();
              } else {
                menucontroller.open();
              }
            },
          ),
        ),
      ),
    );
  }
}
