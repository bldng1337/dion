import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse/browse.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
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

class PseudoCategory implements Category {
  @override
  final String name;
  final DataSource<EntrySaved> entriesource;

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

  @override
  void initState() {
    Observer(
      () async {
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
      },
      locate<Database>().getListenable(DBEvent.categoryUpdated),
    ).disposedBy(scope);

    if (settings.library.showAllTab.value) {}
    if (settings.library.showNoneTab.value) {}
    super.initState();
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
    return NavScaff(
      destination: homedestinations,
      child: DionTabBar(
        scrollable: true,
        tabs: [
          for (final cat in categories)
            DionTab(
              child: CategoryDisplay(category: cat, key: ValueKey(cat)),
              tab: Row(
                children: [
                  Text(cat.name),
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child:
                          (categoryCounts[cat] != null &&
                              categoryCounts[cat]! > 0)
                          ? DionContainer(
                              key: ValueKey('badge_${cat.name}'),
                              color: context.theme.primaryColor,
                              child: Text(
                                '${categoryCounts[cat]}',
                                textAlign: TextAlign.center,
                                style: context.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ).paddingHorizontal(3),
                            )
                          : SizedBox.shrink(key: ValueKey('empty_${cat.name}')),
                    ),
                  ).paddingAll(3),
                ],
              ),
            ),
          if (settings.library.showAllTab.value)
            DionTab(
              tab: Row(
                children: [
                  const Text('All'),
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: (totalCount != null && totalCount! > 0)
                          ? DionContainer(
                              key: const ValueKey('badge_all'),
                              color: context.theme.primaryColor,
                              child: Text(
                                '$totalCount',
                                textAlign: TextAlign.center,
                                style: context.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ).paddingHorizontal(3),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty_all')),
                    ),
                  ),
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
                children: [
                  const Text('No Category'),
                  SizedBox(
                    width: 17,
                    height: 17,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: (noneCount != null && noneCount! > 0)
                          ? DionContainer(
                              key: const ValueKey('badge_no_category'),
                              color: context.theme.primaryColor,
                              child: Text(
                                '$noneCount',
                                textAlign: TextAlign.center,
                                style: context.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ).paddingHorizontal(3),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty_no_category'),
                            ),
                    ),
                  ).paddingAll(3),
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
      locate<Database>().getListenable(DBEvent.entryAddedOrRemoved),
      callOnInit: false,
    ).disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicGrid<EntrySaved>(
      showDataSources: false,
      itemBuilder: (BuildContext context, item) =>
          EntryDisplay(entry: item, showSaved: false),
      controller: controller,
    );
  }
}
