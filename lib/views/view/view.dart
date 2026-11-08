import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/safe_set_state.dart';
import 'package:dionysos/views/view/audio/audio.dart';
import 'package:dionysos/views/view/epub/epub.dart';
import 'package:dionysos/views/view/imagelist/image.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/views/view/pdf/pdf.dart';
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

  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is! List<Object?>) throw Exception('Invalid extra');
    if (supplier == null) {
      supplier = SourceSupplier(extra[0]! as EpisodePath)..disposedBy(scope);
      Observer(
        () async {
          final generation = ++_loadGeneration;
          final source = await supplier!.cache.get(supplier!.episode);
          if (generation != _loadGeneration) return;
          safeSetState(() {
            if (source.isSuccess) {
              lastsource = source.getOrThrow;
              error = null;
            } else {
              error = source.exceptionOrNull;
            }
          });
        },
        supplier!,
        callIndirectly: false,
      ).disposedBy(scope);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (supplier == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return SourceSuplierData(
      supplier: supplier!,
      child: Session(source: supplier!, child: buildWidget(context)),
    );
  }

  Widget buildWidget(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: const Text('Error'),
        child: ErrorDisplay(
          e: error,
          message: 'Error loading source',
          actions: [
            ErrorAction(
              label: 'Retry',
              onTap: () {
                setState(() => error = null);
                supplier!.retry();
              },
            ),
          ],
        ),
      );
    }
    if (lastsource == null) {
      return const NavScaff(
        title: Text('Loading...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return switch (lastsource!.source) {
      final Source_Paragraphlist _ => const ParagraphListReader(),
      final Source_Epub _ => const EpubReader(),
      final Source_Pdf _ => const PdfReader(),
      final Source_Imagelist _ => const ImageListReader(),
      final Source_Video _ => const VideoPlayer(),
      final Source_Audio _ => const AudioListener(),
    };
  }
}
