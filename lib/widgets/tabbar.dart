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
  const DionTabBar({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => MaterialTabBar(tabs: tabs),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}

class MaterialTabBar extends StatefulWidget {
  final List<DionTab> tabs;
  const MaterialTabBar({super.key, required this.tabs});

  @override
  State<MaterialTabBar> createState() => _MaterialTabBarState();
}

class _MaterialTabBarState extends State<MaterialTabBar>
    with TickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    controller = TabController(length: widget.tabs.length, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if(controller.length != widget.tabs.length){
      controller = TabController(length: widget.tabs.length, vsync: this);
    }
    return Column(
      children: [
        TabBar(
          tabs: widget.tabs.map((e) => e.tab.paddingAll(5)).toList(),
          controller: controller,
        ),
        TabBarView(
          controller: controller,
          children: widget.tabs.map((e) => e.child).toList(),
        ).expanded(),
      ],
    );
  }
}
