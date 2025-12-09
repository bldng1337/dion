import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/audio/audio.dart';
import 'package:dionysos/views/view/imagelist/image.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/views/view/video/video.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';

class ViewSource extends StatefulWidget {
  const ViewSource({super.key});

  @override
  _ViewSourceState createState() => _ViewSourceState();
}

class _ViewSourceState extends State<ViewSource> with StateDisposeScopeMixin {
  SourceSupplier? supplier;
  SourcePath? lastsource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is! List<Object?>) throw Exception('Invalid extra');
    if (supplier == null) {
      supplier = SourceSupplier(extra[0]! as EpisodePath)..disposedBy(scope);
      Observer(() async {
        final source = await supplier!.cache.get(supplier!.episode);
        if (source.isSuccess) {
          setState(() {
            lastsource = source.getOrThrow;
          });
        }
      }, supplier!).disposedBy(scope);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (lastsource == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: DionProgressBar(),
      );
    }
    return switch (lastsource!.source) {
      final Source_Paragraphlist _ => ParagraphListReader(supplier: supplier!),
      final Source_Epub _ => throw UnimplementedError('Epub not supported yet'),
      final Source_Pdf _ => throw UnimplementedError('Pdf not supported yet'),
      final Source_Imagelist _ => ImageListReader(supplier: supplier!),
      final Source_M3u8 _ => VideoPlayer(supplier: supplier!),
      final Source_Mp3 _ => AudioListener(supplier: supplier!),
    };
  }
}
