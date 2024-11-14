
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  _LibraryState createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      child: DynamicGrid<Entry>(
        itemBuilder: (BuildContext context, item) => EntryCard(entry: item),
        sources: [
          SingleStreamSource((i) => locate<Database>().getEntries(i, 25)),
        ],
      ),
    );
  }
}
