import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/audio/audio.dart';
import 'package:dionysos/views/view/imagelist/image.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/views/view/video/video.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:inline_result/inline_result.dart';

class SourceSuplierData extends InheritedWidget {
  final SourceSupplier supplier;

  const SourceSuplierData({
    super.key,
    required this.supplier,
    required super.child,
  });

  static SourceSuplierData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SourceSuplierData>();
  }

  @override
  bool updateShouldNotify(covariant SourceSuplierData oldWidget) {
    return supplier != oldWidget.supplier;
  }
}


class ViewSource extends StatefulWidget {
  const ViewSource({super.key});

  @override
  _ViewSourceState createState() => _ViewSourceState();
}

class _ViewSourceState extends State<ViewSource> with StateDisposeScopeMixin {
  SourceSupplier? supplier;
  SourcePath? lastsource;
  Object? error;

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
        } else {
          setState(() {
            error = source.exceptionOrNull;
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
    if (supplier == null) {
      return const NavScaff(
        title: Text('Loading(This should not happen)...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return SourceSuplierData(
      supplier: supplier!,
      child: Session(
        source: supplier!,
        child: buildWidget(context),
      ),
    );
  }


  Widget buildWidget(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: const Text('Error'),
        child: Center(child: Text('Error loading source: $error')),
      );
    }
    if (lastsource == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return switch (lastsource!.source) {
      final Source_Paragraphlist _ => ParagraphListReader(),
      final Source_Epub _ => const NavScaff(
        title: Text('Not Supported'),
        child: ErrorDisplay(
          message: 'Epub sources are not supported yet.', e: null,
        ),
      ),
      final Source_Pdf _ => const NavScaff(
        title: Text('Not Supported'),
        child: ErrorDisplay(
          message: 'Pdf sources are not supported yet.', e: null,
        ),
      ),
      final Source_Imagelist _ => ImageListReader(),
      final Source_Video _ => VideoPlayer(),
      final Source_Audio _ => AudioListener(),
    };
  }
}
