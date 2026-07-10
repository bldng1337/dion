import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/library/library_query.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse/browse.dart';
import 'package:dionysos/views/browse/library_filter_panel.dart';
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

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

class _LibraryTab {
  final String label;
  final EntryScope scope;

  const _LibraryTab(this.label, this.scope);

  @override
  bool operator ==(Object other) =>
      other is _LibraryTab && other.label == label && other.scope == scope;

  @override
  int get hashCode => Object.hash(label, scope);
}

class _LibraryState extends State<Library> with StateDisposeScopeMixin {
  List<Category>? categories;
  // Counts keyed by the tab's scope, so badges reflect the active filters.
  Map<EntryScope, int> counts = {};

  LibraryFilters _filters = LibraryFilters.empty;
  late LibrarySort _sort = LibrarySort(
    key: settings.library.sortKey.value,
    descending: settings.library.sortDescending.value,
  );

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
        _refreshCounts();
      }
    }, locate<Database>().globalListenable).disposedBy(scope);

    super.initState();
  }

  void _refreshCounts() {
    for (final tab in _visibleTabs) {
      _countScope(tab.scope);
    }
  }

  Future<void> _countScope(EntryScope scope) async {
    final count = await locate<Database>().countEntries(
      scope: scope,
      filters: _filters,
    );
    if (!mounted) return;
    setState(() => counts[scope] = count);
  }

  List<_LibraryTab> get _visibleTabs {
    final cats = categories ?? const <Category>[];
    return [
      for (final cat in cats) _LibraryTab(cat.name, EntryScopeCategory(cat)),
      if (settings.library.showAllTab.value)
        const _LibraryTab('All', EntryScopeAll()),
      if (settings.library.showNoneTab.value)
        const _LibraryTab('No Category', EntryScopeUncategorized()),
    ];
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

  void _openFilters() {
    showLibraryFilterPanel(
      context,
      filters: _filters,
      sort: _sort,
      onFiltersChanged: (next) {
        setState(() {
          _filters = next;
          counts = {}; // clear stale counts while they recompute
        });
        _refreshCounts();
      },
      onSortChanged: (next) => setState(() => _sort = next),
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
    final filtersActive = _filters.isActive;
    return NavScaff(
      destination: homedestinations,
      title: const Text('Library'),
      actions: [
        DionIconbutton(
          icon: Icon(
            filtersActive ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          onPressed: _openFilters,
        ),
        DionIconbutton(
          icon: const Icon(Icons.search),
          onPressed: _toggleSearch,
        ),
      ],
      child: DionTabBar(
        scrollable: true,
        tabs: [
          for (final tab in _visibleTabs)
            DionTab(
              child: EntryGrid(
                key: ValueKey(tab),
                scope: tab.scope,
                filters: _filters,
                sort: _sort,
              ),
              tab: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  _CountBadge(count: counts[tab.scope]).paddingOnly(left: 5),
                ],
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

class EntryGrid extends StatefulWidget {
  final EntryScope scope;
  final LibraryFilters filters;
  final LibrarySort sort;

  const EntryGrid({
    super.key,
    required this.scope,
    this.filters = LibraryFilters.empty,
    this.sort = const LibrarySort(),
  });

  @override
  State<EntryGrid> createState() => _EntryGridState();
}

class _EntryGridState extends State<EntryGrid>
    with StateDisposeScopeMixin, AutomaticKeepAliveClientMixin {
  DataSourceController<EntrySaved>? controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    _rebuildController();
    Observer(
      () {
        if (mounted && controller != null) {
          controller!.reset();
          controller!.requestMore();
        }
      },
      locate<Database>().globalListenable,
      callOnInit: false,
    ).disposedBy(scope);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant EntryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.filters != widget.filters ||
        oldWidget.sort != widget.sort) {
      _rebuildController();
    }
  }

  void _rebuildController() {
    controller?.dispose();
    controller = DataSourceController<EntrySaved>([
      SingleStreamSource(
        (i) => locate<Database>().queryEntries(
          scope: widget.scope,
          filters: widget.filters,
          sort: widget.sort,
          page: i,
        ),
      ),
    ]);
    controller!.requestMore();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = this.controller;
    if (controller == null) {
      return const Center(child: DionProgressBar());
    }
    return DynamicGrid<EntrySaved>(
      showDataSources: false,
      itemBuilder: (BuildContext context, item) =>
          EntryDisplay(entry: item, showSaved: false),
      controller: controller,
    );
  }
}

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
                borderRadius: DionRadius.small,
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
