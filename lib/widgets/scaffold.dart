import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/theme.dart';
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

  const NavScaff({
    super.key,
    required this.child,
    this.destination = const [],
    this.actions,
    this.title,
  });

  Widget bottomNavBar(BuildContext context, int index) {
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
          appBar: AppBar(
            title: title,
            actions: actions,
          ),
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index >= 0 ? index : 0,
            items: destination
                .map(
                  (e) => BottomNavigationBarItem(
                    icon: Icon(e.ico),
                    label: e.name,
                  ),
                )
                .toList(),
            onTap: (i) => context.go(destination[i].path),
          ),
        )
    };
  }

  @override
  Widget build(BuildContext context) {
    final int index = destination.indexWhere(
      (element) =>
          GoRouterState.of(context).fullPath?.startsWith(element.path) ?? false,
    );
    if (!context.showNavbar) {
      return bottomNavBar(context, index);
    }
    return switch (context.diontheme.mode) {
      DionThemeMode.material => Scaffold(
          body: Row(
            children: [
              LayoutBuilder(
                builder: (context, constraint) {
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraint.maxHeight),
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
          appBar: AppBar(
            title: title,
            actions: actions,
          ),
        )
    };
  }
}
