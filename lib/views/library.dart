import 'dart:async';

import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse.dart';
import 'package:dionysos/views/settings/library.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:metis/metis.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

class PseudoCategory implements Category {
  final String name;
  final DataSource<EntrySaved> entriesource;

  const PseudoCategory(this.name, this.entriesource);

  @override
  Category copyWith({String? name, DBRecord? id}) {
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
  Map<Category, DataSourceController<EntrySaved>> controllers = {};

  void setCategory(Category cat) {
    controllers[cat] = DataSourceController<EntrySaved>([cat.getEntries()]);
  }

  @override
  void initState() {
    Observer(() {
      if (mounted) {
        for (final controller in controllers.values) {
          controller.reset();
          controller.requestMore();
        }
        setState(() {});
      }
    }, [locate<Database>()]).disposedBy(scope);

    if (settings.library.showAllTab.value) {
      setCategory(
        PseudoCategory(
          'All',
          SingleStreamSource((i) => locate<Database>().getEntries(i, 25)),
        ),
      );
    }

    if (settings.library.showNoneTab.value) {
      Future.microtask(() async {
        final db = locate<Database>();
        if (await db.getNumEntriesWithoutCategory() == 0) return;
        setCategory(
          PseudoCategory(
            'No Category',
            SingleStreamSource(
              (i) => locate<Database>().getEntriesWithoutCategory(i, 25),
            ),
          ),
        );
      });
    }
    locate<Database>().getCategories().then((cats) async {
      final db = locate<Database>();
      for (final cat in cats) {
        if (await db.getNumEntries(cat) == 0) continue;
        setCategory(cat);
      }
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      child: controllers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : DionTabBar(
              tabs: [
                for (final cat in controllers.keys)
                  DionTab(
                    tab: Text(cat.name),
                    child: DynamicGrid<EntrySaved>(
                      showDataSources: false,
                      itemBuilder: (BuildContext context, item) =>
                          EntryDisplay(entry: item, showSaved: false),
                      controller: controllers[cat]!,
                    ),
                  ),
              ],
              trailing: DionIconbutton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  showAddCategoryDialog(context);
                },
              ),
            ),
    );
  }
}
