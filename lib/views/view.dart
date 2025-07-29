import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/audio_listener.dart';
import 'package:dionysos/views/view/imagelist_reader.dart';
import 'package:dionysos/views/view/paragraphlist_reader.dart';
import 'package:dionysos/views/view/video_player.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart' hide Action;
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewSource extends StatefulWidget {
  const ViewSource({super.key});

  @override
  _ViewSourceState createState() => _ViewSourceState();
}

class _ViewSourceState extends State<ViewSource> with StateDisposeScopeMixin {
  SourceSupplier? source;
  SourcePath? lastsource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is! List<Object?>) throw Exception('Invalid extra');
    if (source == null) {
      source = SourceSupplier(extra[0]! as EpisodePath)..disposedBy(scope);
      source!.sourcestream.listen((source) {
        setState(() {
          lastsource = source;
        });
      });
      Observer(() => Future.microtask(() => setState(() {})), [
        source!,
      ]).disposedBy(scope);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  int getState() {
    if (source!.haserror) return 0;
    if (source!.source != null) return 1;

    if (source == null) return 2;
    if (source!.loading) return 2;
    return 2;
    // TODO: Maybe have an extra state for this or log it
    // also maybe SourceSupplier should provide an enum for its state like DionMapCache
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: getState(),
      children: [
        NavScaff(
          title: Text('Error Loading ${source?.episode.name ?? ''}'),
          child: ErrorDisplay(
            e: source?.error,
            s: source?.stacktrace,
            message: 'Error Loading ${source?.episode.name ?? ''}',
            actions: getActions(),
          ),
        ),
        getView(),
        NavScaff(
          title: Text('Loading ${source?.episode.name ?? ''} ...'),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  List<ErrorAction> getActions() {
    return [
      ErrorAction(
        label: 'Refresh',
        onTap: () async {
          source?.invalidateCurrent();
        },
      ),
      ErrorAction(
        label: 'Open in Browser',
        onTap: () async {
          await launchUrl(Uri.parse(source!.episode.episode.url));
        },
      ),
    ];
  }

  Widget getView() {
    if (lastsource == null) {
      return Container();
    }
    if (source == null) {
      logger.e('Unexpected State: source is null');
      return Container();
    }
    return switch (lastsource!.source) {
      final Source_Data data => switch (data.sourcedata) {
        final DataSource_Paragraphlist _ => SimpleParagraphlistReader(
          source: lastsource!,
          supplier: source!,
        ),
      },
      final Source_Directlink link => switch (link.sourcedata) {
        final LinkSource_Epub _ => throw UnimplementedError(
          'Epub not supported yet',
        ),
        final LinkSource_Pdf _ => throw UnimplementedError(
          'Pdf not supported yet',
        ),
        final LinkSource_Imagelist _ => SimpleImageListReader(
          source: lastsource!,
          supplier: source!,
        ),
        final LinkSource_M3u8 _ => SimpleVideoPlayer(source: source!),
        final LinkSource_Mp3 _ => SimpleAudioListener(source: source!),
      },
    };
  }
}
