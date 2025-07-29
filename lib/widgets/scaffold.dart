import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Destination {
  final IconData ico;
  final String name;
  final String path;
  Destination({required this.ico, required this.name, required this.path});
}

class NavScaff extends StatelessWidget {
  final Widget child;
  final List<Destination> destination;
  final List<Widget>? actions;
  final Widget? title;
  final Widget? floatingActionButton;

  const NavScaff({
    super.key,
    required this.child,
    this.destination = const [],
    this.actions,
    this.title,
    this.floatingActionButton,
  });

  Widget bottomNavBar(BuildContext context, int index) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
        floatingActionButton: floatingActionButton,
        appBar: AppBar(title: title, actions: actions),
        body: child,
        bottomNavigationBar: NavigationBar(
          backgroundColor: context.backgroundColor,
          selectedIndex: index >= 0 ? index : 0,
          destinations: destination
              .map(
                (e) => NavigationDestination(icon: Icon(e.ico), label: e.name),
              )
              .toList(),
          onDestinationSelected: (i) => context.go(destination[i].path),
        ),
      ),
      DionThemeMode.cupertino => CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: index >= 0 ? index : 0,
          items: destination
              .map(
                (e) =>
                    BottomNavigationBarItem(icon: Icon(e.ico), label: e.name),
              )
              .toList(),
          onTap: (i) => context.go(destination[i].path),
        ),
        tabBuilder: (context, index) => CupertinoTabView(
          builder: (context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: title,
              trailing: Row(children: actions ?? []),
            ),
            child: child.paddingOnly(top: 45),
          ),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final int index = destination.indexWhere(
      (element) =>
          GoRouterState.of(context).fullPath?.startsWith(element.path) ?? false,
    );
    if (!context.showNavbar && destination.length > 1) {
      return bottomNavBar(context, index);
    }
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
        floatingActionButton: floatingActionButton,
        body: GestureDetector(
          onTap: ContextMenuController.removeAny,
          child: Row(
            children: [
              if (destination.length > 1)
                LayoutBuilder(
                  builder: (context, constraint) {
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraint.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              backgroundColor: Theme.of(context).highlightColor,
                              onDestinationSelected: (i) =>
                                  context.go(destination[i].path),
                              labelType: NavigationRailLabelType.all,
                              destinations: destination
                                  .map(
                                    (e) => NavigationRailDestination(
                                      icon: Icon(e.ico),
                                      label: Text(e.name),
                                    ),
                                  )
                                  .toList(),
                              selectedIndex: index >= 0 ? index : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Expanded(child: child),
            ],
          ),
        ),
        appBar: AppBar(
          title: title,
          actions: actions,
          leading: destination.isEmpty ? null : nil,
        ),
      ),
      DionThemeMode.cupertino => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: title,
          trailing: Row(
            children: [const Spacer(), if (actions != null) ...actions!],
          ),
        ),
        child: Row(
          children: [
            if (destination.length > 1)
              Container(
                width: 130,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: CupertinoColors.systemGrey4,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: destination
                      .map(
                        (e) => CupertinoButton(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(e.ico).paddingAll(5),
                              Text(e.name).expanded(),
                            ],
                          ),
                          onPressed: () => context.go(e.path),
                        ),
                      )
                      .toList(),
                ),
              ),
            child.expanded(),
          ],
        ).paddingOnly(top: 45),
      ),
    };
  }
}
