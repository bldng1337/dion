import 'package:dionysos/data/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

class _LibraryState extends State<Library> with StateDisposeScopeMixin {
  late final DataSourceController<Entry> datacontroller;

  @override
  void initState() {
    datacontroller = DataSourceController<Entry>(
      [SingleStreamSource((i) => locate<Database>().getEntries(i, 25))],
    );
    Observer(
      () {
        if (mounted) {
          datacontroller.reset();
          datacontroller.requestMore();
          setState(() {});
        }
      },
      [locate<Database>()],
    ).disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      child: DynamicGrid<Entry>(
        showDataSources: false,
        itemBuilder: (BuildContext context, item) => EntryCard(entry: item),
        controller: datacontroller,
      ),
    );
  }
}
