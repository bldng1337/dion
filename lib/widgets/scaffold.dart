






import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
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
  const NavScaff({
    super.key,
    required this.child,
    required this.destination,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final int index = destination.indexWhere(
      (element) =>
          GoRouterState.of(context).fullPath?.startsWith(element.path) ?? false,
    );

    if (!context.showNavbar) {
      return PlatformScaffold(
        appBar: PlatformAppBar(
          title: Text(index >= 0 ? destination[index].name : ''),
          trailingActions: actions,
        ),
        body: child,
        bottomNavBar: PlatformNavBar(
          items: destination
              .map(
                (e) => BottomNavigationBarItem(
                  icon: Icon(e.ico),
                  label: e.name,
                ),
              )
              .toList(),
          itemChanged: (i) => context.go(destination[i].path),
          currentIndex: index >= 0 ? index : 0,
        ),
      );
    }
    final Widget navrail = NavigationRail(
      backgroundColor: Theme.of(context).highlightColor,
      onDestinationSelected: (i) => context.go(destination[i].path),
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
    );
    return PlatformScaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraint) {
              return ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraint.maxHeight),
                    child: IntrinsicHeight(
                      child: navrail,
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(child: child),
        ],
      ),
      appBar: PlatformAppBar(
        title: Text(index >= 0 ? destination[index].name : ''),
        trailingActions: actions,
      ),
    );
  }
}
