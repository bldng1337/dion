import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Hack: As a convenience for clients, we automatically wrap Box layout builders in a SliverToBoxAdapter
// for the CustomScrollView. Since there doesn't seem to be a way to tell if a particular widget is a sliver, we need to check
// all classes that are considered slivers. In the future hopefully there is a single sliver check we can use.
bool isSliver(Widget widget) {
  return widget is SliverAnimatedList ||
      widget is SliverList ||
      widget is SliverGrid ||
      widget is SliverAnimatedOpacity ||
      widget is SliverAppBar ||
      widget is SliverPersistentHeader ||
      widget is SliverFadeTransition ||
      widget is SliverFillRemaining ||
      widget is SliverFillViewport ||
      widget is SliverFixedExtentList ||
      widget is SliverIgnorePointer ||
      widget is SliverMultiBoxAdaptorElement ||
      widget is SliverToBoxAdapter ||
      widget is SliverLayoutBuilder ||
      widget is SliverOffstage ||
      widget is SliverOpacity ||
      widget is SliverOverlapAbsorber ||
      widget is SliverPrototypeExtentList ||
      widget is SliverReorderableList ||
      widget is SliverSafeArea ||
      widget is SliverVisibility ||
      widget is CupertinoSliverRefreshControl ||
      widget is SliverOverlapInjector ||
      widget is RenderSliverOverlapInjector ||
      widget is SliverFadeTransition;
}
