import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

class Browse extends StatefulWidget {
  const Browse({super.key});

  @override
  _BrowseState createState() => _BrowseState();
}

class _BrowseState extends State<Browse> with StateDisposeScopeMixin {
  late final TextEditingController controller;
  late final DataSourceController<Entry> datacontroller;
  late final CancelToken? token;
  @override
  void initState() {
    controller = TextEditingController()..disposedBy(scope);
    datacontroller = DataSourceController<Entry>(
      locate<SourceExtension>()
          .getExtensions(extfilter: (e) => e.isenabled)
          .map(
            (e) => AsyncSource<Entry>((i) => e.browse(i, Sort.popular))
              ..name = e.data.name,
          )
          .toList(),
    )..disposedBy(scope);
    token = CancelToken()..disposedBy(scope);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      destination: homedestinations,
      child: Column(
        children: [
          DionSearchbar(
            controller: controller,
            hintText: 'Search',
            style: const WidgetStatePropertyAll(TextStyle(fontSize: 20)),
            keyboardType: TextInputType.text,
            hintStyle:
                const WidgetStatePropertyAll(TextStyle(color: Colors.grey)),
            onSubmitted: (s) => context.go('/search/$s'),
          ).paddingAll(5),
          DynamicGrid<Entry>(
            itemBuilder: (BuildContext context, item) => EntryCard(entry: item),
            controller: datacontroller,
          ).expanded(),
        ],
      ),
    );
  }
}
