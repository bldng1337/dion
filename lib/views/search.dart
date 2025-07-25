import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/browse.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> with StateDisposeScopeMixin {
  late final TextEditingController controller;
  DataSourceController<Entry>? datacontroller;
  late List<Extension> extensions;
  String? lastquery;
  CancelToken? token;

  @override
  void didChangeDependencies() {
    print('Search didChangeDependencies');
    final query = GoRouterState.of(context).pathParameters['query'] ?? '';
    print('Got query $query');
    if (query == (lastquery ?? '')) return;
    print('Query valid $query');
    lastquery = query;
    search(query);
    controller.text = query;
    super.didChangeDependencies();
  }

  Future<void> search(String query) async {
    print('Searching for $query');
    if (!(token?.isDisposed ?? true)) {
      token!.cancel();
      token!.dispose();
    }
    token = CancelToken()..disposedBy(scope);
    print('swapping datacontroller');
    datacontroller?.dispose();
    datacontroller = DataSourceController<Entry>(
      extensions
          .map(
            (e) => AsyncSource<Entry>(
              (i) async {
                if (token?.isDisposed ?? true) return [];
                final res=await e.search(
                  i,
                  query,
                  // token: token,
                );
                print('Got ${res.length} results');
                return res;
              },
            )..name = e.data.name,
          )
          .toList(),
    );
    datacontroller!.requestMore();
    print('swapped datacontroller');
    // setState(() {});
  }

  @override
  void initState() {
    controller = TextEditingController()..disposedBy(scope);
    extensions =
        locate<SourceExtension>().getExtensions(extfilter: (e) => e.isenabled);
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
            onSubmitted: (s) {
              if (s.isEmpty) {
                context.go('/browse');
                return;
              }
              print('Going to search $s');
              context.go('/search/$s');
            },
          ).paddingAll(5),
          DynamicGrid<Entry>(
            itemBuilder: (BuildContext context, item) =>
                EntryDisplay(entry: item),
            controller: datacontroller!,
          ).expanded(),
        ],
      ),
    );
  }
}
