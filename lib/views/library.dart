import 'package:dionysos/data/Category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

class _LibraryState extends State<Library> with StateDisposeScopeMixin {
  late final DataSourceController<EntrySaved> datacontroller;
  Map<Category, DataSourceController<EntrySaved>> controllers = {};

  @override
  void initState() {
    datacontroller = DataSourceController<EntrySaved>([
      SingleStreamSource((i) => locate<Database>().getEntries(i, 25)),
    ]);
    Observer(() {
      if (mounted) {
        datacontroller.reset();
        datacontroller.requestMore();
        for (final controller in controllers.values) {
          controller.reset();
          controller.requestMore();
        }
        setState(() {});
      }
    }, [locate<Database>()]).disposedBy(scope);
    locate<Database>().getCategories().then((cats) {
      for (final cat in cats) {
        controllers[cat] = DataSourceController<EntrySaved>([
          SingleStreamSource(
            (i) => locate<Database>().getEntriesInCategory(cat, i, 25),
          ),
        ]);
      }
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (controllers.isEmpty) {
      return NavScaff(
        destination: homedestinations,
        child: DynamicGrid<EntrySaved>(
          showDataSources: false,
          itemBuilder: (BuildContext context, item) =>
              EntryDisplay(entry: item, showSaved: false),
          controller: datacontroller,
        ),
      );
    }
    return NavScaff(
      destination: homedestinations,
      child: DionTabBar(
        tabs: [
          DionTab(
            tab: const Text('All'),
            child: DynamicGrid<EntrySaved>(
              showDataSources: false,
              itemBuilder: (BuildContext context, item) =>
                  EntryDisplay(entry: item, showSaved: false),
              controller: datacontroller,
            ),
          ),
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
      ),
    );
  }
}
