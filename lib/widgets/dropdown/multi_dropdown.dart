import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

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
  final Widget? defaultItem;
  final List<MultiDropdownItem<T>>? items;
  // ignore: avoid_futureor_void
  final FutureOr<void> Function(List<T>)? onSelectionChange;
  final MultiDropdownController<T>? controller;
  final Widget Function(
    BuildContext context,
    MultiDropdownItem<T> item,
    VoidCallback onTap,
  )?
  buildItem;
  final ButtonType buttonType;
  final Widget? trailing;

  const DionMultiDropdown({
    super.key,
    this.defaultItem,
    this.items,
    this.onSelectionChange,
    this.controller,
    this.buildItem,
    this.buttonType = ButtonType.filled,
    this.trailing,
  });

  @override
  State<DionMultiDropdown<T>> createState() => _DionMultiDropdownState<T>();
}

class _DionMultiDropdownState<T extends Object>
    extends State<DionMultiDropdown<T>>
    with StateDisposeScopeMixin {
  late MultiDropdownController<T> controller;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      controller = MultiDropdownController<T>()..disposedBy(scope);
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
                context.theme.primaryColor.lighten(30),
              ),
            )
          : null,
      child: item.widget,
    );
  }

  void _openSheet(
    BuildContext context,
    Function(FutureOr<void> future) setFuture, // ignore: avoid_futureor_void
  ) {
    showDionDrawer(
      context: context,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: DionSpacing.sm),
            children: [
              for (final (index, item) in controller.items.indexed)
                _MultiDropdownSheetRow<T>(
                  item: item,
                  onTap: () {
                    controller.toggleIndex(index);
                    setFuture(
                      widget.onSelectionChange?.call(
                        controller.selected
                            .where((e) => e.selected)
                            .map((e) => e.value)
                            .toList(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.buildItem ?? _buildItem;
    return Loadable(
      loading:
          const BoundsWidget(
            child: DionTextbutton(
              child: Row(mainAxisAlignment: MainAxisAlignment.center),
            ),
          ).applyShimmer(
            highlightColor: context.theme.scaffoldBackgroundColor.lighten(20),
            baseColor: context.theme.scaffoldBackgroundColor,
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
            type: widget.buttonType,
            child: Row(
              children: [
                if (widget.defaultItem != null &&
                    !controller.items.any((e) => e.selected))
                  widget.defaultItem!,
                ...controller.items
                    .where((e) => e.selected)
                    .map((e) => e.widget.paddingAll(10)),
                if (widget.trailing != null) ...[
                  const Spacer(),
                  widget.trailing!,
                ],
              ],
            ),
            onPressed: () {
              if (isMobilePlatform) {
                _openSheet(context, setFuture);
                return;
              }
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

class _MultiDropdownSheetRow<T extends Object> extends StatelessWidget {
  const _MultiDropdownSheetRow({required this.item, required this.onTap});

  final MultiDropdownItem<T> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DionSpacing.lg,
          vertical: DionSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: DionTypography.bodyLarge(
                  item.selected
                      ? context.theme.colorScheme.primary
                      : context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: item.widget,
              ),
            ),
            const SizedBox(width: DionSpacing.md),
            Icon(
              item.selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: item.selected
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
