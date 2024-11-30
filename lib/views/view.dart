import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/imagelist_reader.dart';
import 'package:dionysos/views/view/paragraphlist_reader.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

class ViewSource extends StatefulWidget {
  const ViewSource({super.key});

  @override
  _ViewSourceState createState() => _ViewSourceState();
}

class _ViewSourceState extends State<ViewSource> with StateDisposeScopeMixin {
  SourcePath? source;
  CancelToken? tok;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is! List<Object?>) return;
    if (extra.isEmpty) return;
    if (extra[0]! is! EpisodePath) return;
    final eppath = extra[0]! as EpisodePath;
    if (source != null && source!.episode == eppath) return;
    if (loading) return;
    if (tok?.isDisposed ?? true) {
      tok = CancelToken()..disposedBy(scope);
    }
    loading = true;
    locate<SourceExtension>().source(eppath, token: tok).then((src) {
      if (mounted) {
        setState(() {
          loading = false;
          source = src;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (source == null) {
      return const NavScaff(
        title: Text('Loading ...'),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return getView(source!);
  }

  Widget getView(SourcePath source) {
    return switch (source.source) {
      final Source_Data data => switch (data.sourcedata) {
          final DataSource_Paragraphlist _ => SimpleParagraphlistReader(
              source: source,
            ),
        },
      final Source_Directlink link => switch (link.sourcedata) {
          final LinkSource_Epub _ => throw UnimplementedError(),
          final LinkSource_Pdf _ => throw UnimplementedError(),
          final LinkSource_Imagelist _ => SimpleImageListReader(source: source),
          final LinkSource_M3u8 _ => throw UnimplementedError(),
        },
    };
  }
}
