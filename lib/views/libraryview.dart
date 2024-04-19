import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/views/entrybrowseview.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:dionysos/sync.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:endless/endless.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  @override
  void initState() {
    super.initState();

    isar.entrySaveds.watchLazy().listen((event) {
      if (!mounted) {
        return;
      }
      reload();
    });
  }

  QueryBuilder<EntrySaved, EntrySaved, QAfterSortBy> sortQuery(
      QueryBuilder<EntrySaved, EntrySaved, QAfterFilterCondition> q) {
    bool desc = LibrarySettings.sortdesc.value;
    switch (LibrarySettings.sortcategory.value) {
      case "epsuncompleted":
        if (desc) {
          return q.sortByEpisodesnotcompletedDesc();
        }
        return q.sortByEpisodesnotcompleted();
      case "epscompleted":
        if (desc) {
          return q.sortByEpisodescompletedDesc();
        }
        return q.sortByEpisodescompleted();
      case "epstotal":
        if (desc) {
          return q.sortByTotalepisodesDesc();
        }
        return q.sortByTotalepisodes();
    }
    return q.sortByTotalepisodes();
  }

  Map<String, EndlessPaginationController<EntrySaved>> controlmap = {};
  EndlessPaginationController<EntrySaved> defaultcontrol =
      EndlessPaginationController();
  static const pagesize = 30;
  Widget buildCategory(Category c) {
    controlmap.putIfAbsent(
        c.name, () => EndlessPaginationController<EntrySaved>());
    // isar.entrySaveds.where().filter().category((q) => q.nameEqualTo(c.name)).watchLazy()
    return EndlessPaginationGridView<EntrySaved>(
        controller: controlmap[c.name],
        loadMore: (index) => sortQuery(isar.entrySaveds
                .where()
                .filter()
                .category((q) => q.nameEqualTo(c.name))
                .optional(
                    LibrarySettings.shouldfiltermediatype.value,
                    (q) => q.anyOf([LibrarySettings.filtermediatype.value],
                        (q, element) => q.typeEqualTo(getMediaType(element))))
                .optional(
                    LibrarySettings.shouldfilterstatus.value,
                    (q) => q.statusEqualTo(
                        getStatus(LibrarySettings.filterstatus.value))))
            .offset(index * pagesize)
            .limit(pagesize)
            .findAll(),
        itemBuilder: (context,
                {required index, required item, required totalItems}) =>
            EntryCard(
              selected: selected.contains(item),
              selection: selected.isNotEmpty,
              onselect: () {
                setState(() {
                  if (selected.contains(item)) {
                    selected.remove(item);
                  } else {
                    selected.add(item);
                  }
                });
              },
              entry: item,
            ),
        paginationDelegate: EndlessPaginationDelegate(
          pageSize: pagesize,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          childAspectRatio: 0.69,
          maxCrossAxisExtent: 220,
        ));
  }

  List<EntrySaved> selected = [];

  Widget defaultTab() {
    return EndlessPaginationGridView<EntrySaved>(
        controller: defaultcontrol,
        loadMore: (index) => sortQuery(isar.entrySaveds
                .where()
                .filter()
                .categoryIsEmpty()
                .optional(
                    LibrarySettings.shouldfiltermediatype.value,
                    (q) => q.anyOf([LibrarySettings.filtermediatype.value],
                        (q, element) => q.typeEqualTo(getMediaType(element))))
                .optional(
                    LibrarySettings.shouldfilterstatus.value,
                    (q) => q.statusEqualTo(
                        getStatus(LibrarySettings.filterstatus.value))))
            .offset(index * pagesize)
            .limit(pagesize)
            .findAll(),
        itemBuilder: (context,
                {required index, required item, required totalItems}) =>
            EntryCard(
              selected: selected.contains(item),
              selection: selected.isNotEmpty,
              onselect: () {
                setState(() {
                  if (selected.contains(item)) {
                    selected.remove(item);
                  } else {
                    selected.add(item);
                  }
                });
              },
              entry: item,
            ),
        paginationDelegate: EndlessPaginationDelegate(
          pageSize: pagesize,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          childAspectRatio: 0.69,
          maxCrossAxisExtent: 220,
        ));
  }

  reload() {
    if (defaultcontrol.isMounted()) {
      defaultcontrol.reload();
    }
    controlmap.forEach(
      (key, value) {
        if (value.isMounted()) {
          value.reload();
        }
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Nav(
      bottom: selected.isEmpty
          ? null
          : SizedBox(
              height: 70,
              child: Row(
                children: [
                  Expanded(
                      child: IconButton(
                    icon: const Icon(Icons.category),
                    onPressed: () {
                      List<bool> categories = List.generate(
                          isar.categorys.countSync(), (index) => false);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                            actions: [
                              TextButton(
                                  onPressed: () {
                                    for (EntrySaved e in selected) {
                                      for (int i = 0;
                                          i < categories.length;
                                          i++) {
                                        Category c = isar.categorys
                                            .where()
                                            .offset(i)
                                            .findFirstSync()!;
                                        if (categories[i]) {
                                          e.category.add(c);
                                        } else {
                                          e.category.remove(c);
                                        }
                                      }
                                    }
                                    Category c =
                                        isar.categorys.where().findFirstSync()!;
                                    isar.writeTxn(() async {
                                      for (EntrySaved e in selected) {
                                        await e.category.save();
                                        await isar.entrySaveds.put(e);
                                      }
                                      await isar.categorys.put(c);
                                    }).then((value) {
                                      setState(() {
                                        Navigator.of(context).pop();
                                        controlmap.forEach((key, value) {
                                          if (value.isMounted()) {
                                            value.reload();
                                          }
                                        });
                                        // defaultcontrol.clear();
                                        selected.clear();
                                        if (defaultcontrol.isMounted()) {
                                          defaultcontrol.reload();
                                        }
                                      });
                                    });
                                    savesync();
                                  },
                                  child: const Text("Submit"))
                            ],
                            title: const Text("Set categories"),
                            content: StatefulBuilder(
                              builder: (context, setState) {
                                return SizedBox(
                                  height: double.maxFinite,
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    itemCount: categories.length,
                                    itemBuilder: (context, index) {
                                      Category c = isar.categorys
                                          .where()
                                          .offset(index)
                                          .findFirstSync()!;
                                      return CheckboxListTile(
                                        title: Text(c.name),
                                        value: categories[index],
                                        onChanged: (bool? value) {
                                          setState(() {
                                            categories[index] = value ?? false;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            )),
                      );
                    },
                  ))
                ],
              ),
            ),
      child: StreamBuilder(
        stream: isar.categorys.where().anyId().watch().asBroadcastStream(),
        initialData: isar.categorys.where().anyId().findAllSync(),
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return defaultTab();
          }
          return ContainedTabBarView(tabs: [
            const Padding(
              padding: EdgeInsets.all(5),
              child: Text("default"),
            ),
            ...snapshot.data!.map((e) => Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(e.name),
                ))
          ], views: [
            defaultTab(),
            ...snapshot.data!.map((e) => buildCategory(e))
          ]);
        },
      ),
    );
  }
}
