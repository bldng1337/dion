import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse/browse.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:metis/metis.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

// ignore: avoid_implementing_value_types
class PseudoCategory implements Category {
  @override
  final String name;
  final DataSource<EntrySaved> entriesource;

  @override
  int get index => 9999999999999;

  const PseudoCategory(this.name, this.entriesource);

  @override
  Category copyWith({String? name, DBRecord? id, int? index}) {
    throw UnimplementedError();
  }

  @override
  DBRecord get dbId => throw UnimplementedError();

  @override
  DBRecord get id => throw UnimplementedError();

  @override
  FutureOr<Map<String, dynamic>> toDBJson() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }

  @override
  DataSource<EntrySaved> getEntries() {
    return entriesource;
  }
}

class _LibraryState extends State<Library> with StateDisposeScopeMixin {
  List<Category>? categories;
  Map<Category, int> categoryCounts = {};
  int? totalCount;
  int? noneCount;

  bool _searching = false;
  String _query = '';
  DataSourceController<EntrySaved>? _searchController;
  Timer? _debounce;
  late final FocusNode _searchFocus = FocusNode()..disposedBy(scope);

  @override
  void initState() {
    Observer(() async {
      if (mounted) {
        final categories = await locate<Database>().getCategories();
        if (!mounted) {
          return;
        }
        setState(() {
          this.categories = categories;
        });
        for (final cat in categories) {
          final count = await locate<Database>().getNumEntriesInCategory(cat);
          if (!mounted) {
            return;
          }
          setState(() {
            categoryCounts[cat] = count;
          });
        }
        final total = await locate<Database>().getNumEntries();
        if (!mounted) {
          return;
        }
        setState(() {
          totalCount = total;
        });
        final none = await locate<Database>().getNumEntriesInCategory(null);
        if (!mounted) {
          return;
        }
        setState(() {
          noneCount = none;
        });
      }
    }, locate<Database>().globalListenable).disposedBy(scope);

    if (settings.library.showAllTab.value) {}
    if (settings.library.showNoneTab.value) {}
    super.initState();
  }

  void _toggleSearch() {
    if (_searching) {
      _exitSearch();
    } else {
      setState(() => _searching = true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    }
  }

  void _exitSearch() {
    _debounce?.cancel();
    _debounce = null;
    _searchController?.dispose();
    _searchController = null;
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  void _runSearch(String query) {
    final trimmed = query.trim();
    if (trimmed == _query) return;
    _query = trimmed;
    _searchController?.dispose();
    if (trimmed.isEmpty) {
      _searchController = null;
      setState(() {});
      return;
    }
    _searchController = DataSourceController<EntrySaved>([
      SingleStreamSource(
        (i) => locate<Database>().searchEntries(trimmed, i, 25),
      ),
    ]);
    setState(() {});
    _searchController!.requestMore();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _runSearch(query),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (categories == null) {
      return NavScaff(
        destination: homedestinations,
        child: const Center(child: DionProgressBar()),
      );
    }
    if (_searching) {
      return NavScaff(
        destination: homedestinations,
        title: const Text('Library'),
        actions: [
          DionIconbutton(icon: const Icon(Icons.close), onPressed: _exitSearch),
        ],
        child: Column(
          children: [
            DionSearchbar(
              focusNode: _searchFocus,
              hintText: 'Search library',
              style: const WidgetStatePropertyAll(TextStyle(fontSize: 20)),
              keyboardType: TextInputType.text,
              hintStyle: const WidgetStatePropertyAll(
                TextStyle(color: Colors.grey),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _runSearch,
            ).paddingAll(5),
            if (_searchController == null)
              const Expanded(
                child: Center(child: Text('Type to search your library')),
              )
            else
              DynamicGrid<EntrySaved>(
                showDataSources: false,
                itemBuilder: (context, item) =>
                    EntryDisplay(entry: item, showSaved: false),
                controller: _searchController!,
              ).expanded(),
          ],
        ),
      );
    }
    return NavScaff(
      destination: homedestinations,
      title: const Text('Library'),
      actions: [
        DionIconbutton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
        ),
      ],
      child: DionTabBar(
        scrollable: true,
        tabs: [
          for (final cat in categories)
            DionTab(
              child: CategoryDisplay(category: cat, key: ValueKey(cat)),
              tab: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.name),
                  _CountBadge(count: categoryCounts[cat]).paddingOnly(left: 5),
                ],
              ),
            ),
          if (settings.library.showAllTab.value)
            DionTab(
              tab: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  _CountBadge(count: totalCount).paddingOnly(left: 5),
                ],
              ),
              child: CategoryDisplay(
                key: const Key('All'),
                category: PseudoCategory(
                  'All',
                  SingleStreamSource(
                    (i) => locate<Database>().getEntries(i, 25),
                  ),
                ),
              ),
            ),
          if (settings.library.showNoneTab.value)
            DionTab(
              tab: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No Category'),
                  _CountBadge(count: noneCount).paddingOnly(left: 5),
                ],
              ),
              child: CategoryDisplay(
                key: const Key('No Category'),
                category: PseudoCategory(
                  'No Category',
                  SingleStreamSource(
                    (i) => locate<Database>().getEntriesInCategory(null, i, 25),
                  ),
                ),
              ),
            ),
        ],
        trailing: DionIconbutton(
          icon: const Icon(Icons.add),
          onPressed: () {
            showAddCategoryDialog(context, categories.length);
          },
        ),
      ),
    );
  }
}

class CategoryDisplay extends StatefulWidget {
  final Category category;

  const CategoryDisplay({super.key, required this.category});

  @override
  _CategoryDisplayState createState() => _CategoryDisplayState();
}

class _CategoryDisplayState extends State<CategoryDisplay>
    with StateDisposeScopeMixin, AutomaticKeepAliveClientMixin {
  late final DataSourceController<EntrySaved> controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    controller = DataSourceController<EntrySaved>([
      widget.category.getEntries(),
    ]);
    Observer(
      () {
        if (mounted) {
          controller.reset();
          controller.requestMore();
        }
      },
      locate<Database>().globalListenable,
      callOnInit: false,
    ).disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DynamicGrid<EntrySaved>(
      showDataSources: false,
      itemBuilder: (BuildContext context, item) =>
          EntryDisplay(entry: item, showSaved: false),
      controller: controller,
    );
  }
}

/// A compact count badge for tab labels.
///
/// Renders as a circle for single digits and grows into a pill for larger
/// numbers, so counts > 9 no longer overflow a fixed-size box. Shows nothing
/// while the count is loading (null) or zero.
class _CountBadge extends StatelessWidget {
  final int? count;

  const _CountBadge({this.count});

  static const double _size = 18;
  static const double _hPad = 5;

  @override
  Widget build(BuildContext context) {
    final value = count;
    final visible = value != null && value > 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? Container(
              key: const ValueKey(true),
              constraints: const BoxConstraints(
                minWidth: _size,
                minHeight: _size,
              ),
              padding: const EdgeInsets.symmetric(horizontal: _hPad),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.theme.primaryColor,
                borderRadius: BorderRadius.circular(_size / 2),
              ),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: context.labelSmall?.copyWith(color: Colors.white),
              ),
            )
          : const SizedBox.shrink(key: ValueKey(false)),
    );
  }
}
