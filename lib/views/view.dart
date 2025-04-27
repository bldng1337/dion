import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/view/audio_listener.dart';
import 'package:dionysos/views/view/imagelist_reader.dart';
import 'package:dionysos/views/view/paragraphlist_reader.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:quiver/cache.dart';
import 'package:quiver/collection.dart';

class ViewSource extends StatefulWidget {
  const ViewSource({super.key});

  @override
  _ViewSourceState createState() => _ViewSourceState();
}

class InheritedPreload extends InheritedWidget {
  final Function() shouldPreload;
  const InheritedPreload({required this.shouldPreload, required super.child});

  @override
  bool updateShouldNotify(InheritedPreload oldWidget) {
    return shouldPreload != oldWidget.shouldPreload;
  }

  static InheritedPreload of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedPreload>()!;
  }
}

class _ViewSourceState extends State<ViewSource> with StateDisposeScopeMixin {
  SourcePath? source;
  CancelToken? tok;
  bool loading = false;
  EpisodePath? eppath;
  Object? error;
  late LruMap<EpisodePath, SourcePath> map;
  late MapCache<EpisodePath, SourcePath> cache;

  Future<SourcePath> getSource(EpisodePath eppath) async {
    if (tok?.isDisposed ?? true) {
      tok = CancelToken()..disposedBy(scope);
    }
    final srcExt = locate<SourceExtension>();
    return await srcExt.source(eppath, token: tok);
  }

  Future<void> loadSource() async {
    try {
      if (loading) return;
      final extra = GoRouterState.of(context).extra;
      if (extra is! List<Object?>) throw Exception('Invalid extra');
      eppath = extra[0]! as EpisodePath;
      if (source != null && source!.episode == eppath) {
        return;
      }
      source = null;
      loading = true;
      final src = await cache.get(eppath!, ifAbsent: getSource);
      if (mounted) {
        setState(() {
          loading = false;
          source = src;
        });
      }
    } catch (e) {
      error = e;
      loading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadSource();
  }

  @override
  void initState() {
    super.initState();
    map = LruMap(maximumSize: 5);
    cache = MapCache(map: map);
  }

  @override
  Widget build(BuildContext context) {
    if (source == null) {
      return NavScaff(
        title: Text('Loading ${eppath?.name ?? ''} ...'),
        child: ErrorBoundary(
          e: error,
          actions: getActions(),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (error != null) {
      return NavScaff(
        title: Text('Error Loading ${eppath?.name ?? ''}'),
        child: ErrorDisplay(
          e: error!,
          actions: getActions(),
        ),
      );
    }
    try {
      return InheritedPreload(
        shouldPreload: () {
          cache.get(eppath!.next, ifAbsent: getSource);
        },
        child: getView(source!),
      );
    } catch (e, s) {
      return NavScaff(
        title: Text('Error Displaying ${eppath?.name ?? ''}'),
        child: ErrorDisplay(
          e: e,
          s: s,
          actions: getActions(),
        ),
      );
    }
  }

  List<ErrorAction> getActions() {
    return [
      if (!loading)
        ErrorAction(
          label: 'Refresh',
          onTap: () async {
            error = null;
            source = null;
            await loadSource();
          },
        ),
    ];
  }

  Widget getView(SourcePath source) {
    return switch (source.source) {
      final Source_Data data => switch (data.sourcedata) {
          final DataSource_Paragraphlist _ => SimpleParagraphlistReader(
              source: source,
            ),
        },
      final Source_Directlink link => switch (link.sourcedata) {
          final LinkSource_Epub _ =>
            throw UnimplementedError('Epub not supported yet'),
          final LinkSource_Pdf _ =>
            throw UnimplementedError('Pdf not supported yet'),
          final LinkSource_Imagelist _ => SimpleImageListReader(source: source),
          final LinkSource_M3u8 _ =>
            throw UnimplementedError('M3u8 not supported yet'),
          final LinkSource_Mp3 _ => SimpleAudioListener(source: source),
        },
    };
  }
}
