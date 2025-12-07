import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class DionTab {
  final Widget child;
  final Widget tab;
  const DionTab({required this.child, required this.tab});
}

class DionTabBar extends StatelessWidget {
  final List<DionTab> tabs;
  final Widget? trailing;
  final bool hideIfSingle;
  final bool scrollable;
  const DionTabBar({
    super.key,
    required this.tabs,
    this.trailing,
    this.hideIfSingle = true,
    this.scrollable = false,
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
      DionThemeMode.material => MaterialTabBar(
        tabs: tabs,
        trailing: trailing,
        scrollable: scrollable,
      ),
      DionThemeMode.cupertino => throw UnimplementedError(),
    };
  }
}

class MaterialTabBar extends StatefulWidget {
  final List<DionTab> tabs;
  final Widget? trailing;
  final bool scrollable;
  const MaterialTabBar({
    super.key,
    required this.tabs,
    this.trailing,
    required this.scrollable,
  });

  @override
  State<MaterialTabBar> createState() => _MaterialTabBarState();
}

class _MaterialTabBarState extends State<MaterialTabBar>
    with TickerProviderStateMixin {
  late TabController controller;

  int get tabcount =>
      widget.tabs.length; // + (widget.trailing != null ? 1 : 0);

  @override
  void initState() {
    createController();
    super.initState();
  }

  void createController() {
    controller = TabController(length: tabcount, vsync: this);
    controller.addListener(() {
      // if (controller.index == tabcount - 1 && widget.trailing != null) {
      //   controller.offset = 0;
      //   final safeIndex = (tabcount - 2).clamp(0, tabcount - 2);
      //   controller.index = safeIndex;
      //   controller.animateTo(safeIndex);
      // }
    });
  }

  @override
  void didUpdateWidget(MaterialTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.length != tabcount) {
      controller.dispose();
      createController();
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
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.theme.colorScheme.surfaceContainer,
                width: 1.5,
              ),
            ),
          ),
          child: _buildTabBar(),
        ),
        TabBarView(
          controller: controller,
          children: widget.tabs.map((e) => e.child).toList(),
        ).expanded(),
      ],
    );
  }

  Widget _buildTabBar() {
    if (widget.trailing == null) {
      return TabBar(
        isScrollable: widget.scrollable,
        tabs: [...widget.tabs.map((e) => e.tab.paddingAll(5))],
        controller: controller,
        dividerColor: Colors.transparent,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: widget.scrollable,
            tabs: [...widget.tabs.map((e) => e.tab.paddingAll(5))],
            controller: controller,
            dividerColor: Colors.transparent,
          ),
          widget.trailing!,
        ],
      ),
    );
  }
}
