import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class DionTab {
  final Widget child;
  final Widget tab;
  const DionTab({required this.child, required this.tab});

  @override
  String toString() {
    return 'Tab{child: $child, tab: $tab}';
  }

  @override
  bool operator ==(Object other) {
    return other is DionTab && other.child == child && other.tab == tab;
  }

  @override
  int get hashCode => Object.hash(child, tab);
}

class DionTabBar extends StatelessWidget {
  final List<DionTab> tabs;
  final Widget? trailing;
  final bool hideIfSingle;
  const DionTabBar({
    super.key,
    required this.tabs,
    this.trailing,
    this.hideIfSingle = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return nil;
    }
    if (hideIfSingle && tabs.length == 1) {
      return tabs.first.child;
    }
    return switch (context.diontheme.mode) {
      DionThemeMode.material => MaterialTabBar(tabs: tabs, trailing: trailing),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}

class MaterialTabBar extends StatefulWidget {
  final List<DionTab> tabs;
  final Widget? trailing;
  const MaterialTabBar({super.key, required this.tabs, this.trailing});

  @override
  State<MaterialTabBar> createState() => _MaterialTabBarState();
}

class _MaterialTabBarState extends State<MaterialTabBar>
    with TickerProviderStateMixin {
  late TabController controller;

  int get tabcount => widget.tabs.length + (widget.trailing != null ? 1 : 0);

  @override
  void initState() {
    controller = TabController(length: tabcount, vsync: this);
    controller.addListener(() {
      if (controller.index == tabcount - 1 && widget.trailing != null) {
        controller.animateTo(max(0, tabcount - 2));
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(MaterialTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.length != tabcount) {
      controller.dispose();
      controller = TabController(length: tabcount, vsync: this);
      controller.addListener(() {
        if (controller.index == tabcount - 1 && widget.trailing != null) {
          controller.animateTo((tabcount - 2).clamp(0, tabcount - 2));
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          isScrollable: true,
          tabs: [
            ...widget.tabs.map((e) => e.tab.paddingAll(5)),
            if (widget.trailing != null) widget.trailing!,
          ],
          controller: controller,
        ),
        TabBarView(
          controller: controller,
          children: [
            ...widget.tabs.map((e) => e.child),
            if (widget.trailing != null) nil,
          ],
        ).expanded(),
      ],
    );
  }
}
