import 'dart:async';
import 'dart:io';

import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart'
    hide
        Alignment,
        ButtonType,
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        StackFit,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/views/view/source_file.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SimplePdfReader extends StatefulWidget {
  final SourcePath source;
  final SourceSupplier supplier;
  Source_Pdf get sourcedata => source.source as Source_Pdf;

  const SimplePdfReader({
    super.key,
    required this.source,
    required this.supplier,
  });

  @override
  State<SimplePdfReader> createState() => _SimplePdfReaderState();
}

class _SimplePdfReaderState extends State<SimplePdfReader>
    with StateDisposeScopeMixin {
  PdfViewerController? _controller;
  int _savedPage = 0;
  late final Future<File> _sourceFile = resolveSourceFile(
    widget.sourcedata.link,
  );

  void _onViewChanged() {
    final controller = _controller;
    if (controller == null || !controller.isReady || !mounted) return;
    final page = controller.pageNumber;
    if (page == null || page == _savedPage) return;
    _savedPage = page;
    final epdata = widget.source.episode.data;
    if (page > 1) {
      epdata.progress = page.toString();
    }
    SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
    if (!epdata.finished && page == controller.pageCount) {
      epdata.finished = true;
      widget.source.episode.save();
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.toggle(enable: true);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onViewChanged);
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    unawaited(
      _sourceFile
          .then((file) => deleteResolvedSource(widget.sourcedata.link, file))
          .catchError((Object e) {
            logger.w('Failed to clean up pdf source file', error: e);
          }),
    );
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    final epdata = widget.source.episode.data;
    epdata.bookmark = !epdata.bookmark;
    await widget.source.episode.save();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final savedPage = epdata.finished
        ? 1
        : int.tryParse(epdata.progress ?? '') ?? 1;
    return NavScaff(
      showNavbar: false,
      child: LoadingBuilder(
        future: _sourceFile,
        loading: (context) => const Center(child: DionProgressBar()),
        error: (context, error, stackTrace) {
          logger.e(
            'Error loading pdf source',
            error: error,
            stackTrace: stackTrace,
          );
          return ErrorDisplay(
            e: error,
            s: stackTrace,
            message: 'Error loading pdf source',
          );
        },
        builder: (context, file) => Stack(
          children: [
            PdfViewer.file(
              file.path,
              initialPageNumber: savedPage,
              params: PdfViewerParams(
                backgroundColor: Theme.of(context).colorScheme.surface,
                onViewerReady: (document, controller) {
                  if (_controller != null) return;
                  _savedPage = controller.pageNumber ?? savedPage;
                  controller.addListener(_onViewChanged);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _controller = controller);
                    }
                  });
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: AppBar(
                  primary: false,
                  title: DionTextScroll(widget.source.name),
                  leading: DionIconbutton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      context.pop();
                    },
                  ),
                  actions: [
                    if (_controller != null)
                      ListenableBuilder(
                        listenable: _controller!,
                        builder: (context, _) {
                          final controller = _controller!;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: DionSpacing.md,
                            ),
                            child: Center(
                              child: Text(
                                '${controller.pageNumber ?? 1} / ${controller.pageCount}',
                                style: DionTypography.bodySmall(
                                  context.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    DionIconbutton(
                      tooltip: epdata.bookmark
                          ? 'Remove Bookmark'
                          : 'Add Bookmark',
                      icon: Icon(
                        epdata.bookmark
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                      onPressed: _toggleBookmark,
                    ),
                    DionIconbutton(
                      tooltip: 'Open in Browser',
                      icon: const Icon(Icons.open_in_browser),
                      onPressed: () => launchUrl(
                        Uri.parse(widget.source.episode.episode.url),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
