import 'dart:async';

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
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/views/view/source_file.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SimpleEpubReader extends StatefulWidget {
  final SourcePath source;
  final SourceSupplier supplier;
  Source_Epub get sourcedata => source.source as Source_Epub;

  const SimpleEpubReader({
    super.key,
    required this.source,
    required this.supplier,
  });

  @override
  State<SimpleEpubReader> createState() => _SimpleEpubReaderState();
}

class _SimpleEpubReaderState extends State<SimpleEpubReader>
    with StateDisposeScopeMixin {
  EpubController? _controller;
  bool _disposed = false;
  DateTime _lastProgressSave = DateTime.now();
  late final Future<EpubController> _loader = _load();

  Future<EpubController> _load() async {
    final epdata = widget.source.episode.data;
    final saved = epdata.finished ? null : epdata.progress;
    final file = await resolveSourceFile(widget.sourcedata.link);
    final bytes = await file.readAsBytes();
    if (!isFileUrl(widget.sourcedata.link.url)) {
      // The book is fully in memory now, the temporary download is dead weight.
      unawaited(deleteResolvedSource(widget.sourcedata.link, file));
    }
    final controller = EpubController(
      document: EpubDocument.openData(bytes),
      epubCfi: saved == null || saved.isEmpty ? null : saved,
    );
    if (_disposed) {
      controller.dispose();
      return controller;
    }
    _controller = controller;
    controller.currentValueListenable.addListener(_onPositionChanged);
    return controller;
  }

  void _onPositionChanged() {
    if (!mounted) return;
    SessionData.of(context)?.manager.keepSessionAlive();
    // CFI generation walks the visible paragraph on every scroll frame;
    // throttling keeps it to one write per second, like the other readers.
    if (DateTime.now().difference(_lastProgressSave) <
        const Duration(seconds: 1)) {
      return;
    }
    _lastProgressSave = DateTime.now();
    final cfi = _controller?.generateEpubCfi();
    if (cfi != null) {
      widget.source.episode.data.progress = cfi;
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.toggle(enable: true);
  }

  @override
  void dispose() {
    _disposed = true;
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    _controller?.currentValueListenable.removeListener(_onPositionChanged);
    _controller?.dispose();
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

  void _showTableOfContents() {
    final controller = _controller;
    if (controller == null) return;
    showDionPanel(
      context: context,
      builder: (dialogContext) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DionSpacing.lg,
                  DionSpacing.lg,
                  DionSpacing.sm,
                  DionSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Table of Contents',
                        style: DionTypography.titleMedium(context.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: EpubViewTableOfContents(
                  controller: controller,
                  itemBuilder: (context, index, chapter, itemCount) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DionSpacing.lg,
                      ),
                      title: Text(
                        chapter.title?.trim() ?? '',
                        style: DionTypography.bodyMedium(context.textPrimary),
                      ),
                      onTap: () {
                        controller.scrollTo(index: chapter.startIndex);
                        Navigator.of(dialogContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    return NavScaff(
      showNavbar: false,
      child: LoadingBuilder(
        future: _loader,
        loading: (context) => const Center(child: DionProgressBar()),
        error: (context, error, stackTrace) {
          logger.e(
            'Error loading epub source',
            error: error,
            stackTrace: stackTrace,
          );
          return ErrorDisplay(
            e: error,
            s: stackTrace,
            message: 'Error loading epub source',
          );
        },
        builder: (context, controller) => Stack(
          children: [
            EpubView(
              controller: controller,
              onExternalLinkPressed: (href) => launchUrl(Uri.parse(href)),
              onDocumentError: (error) =>
                  logger.e('Error loading epub document', error: error),
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
                    DionIconbutton(
                      tooltip: 'Table of Contents',
                      icon: const Icon(Icons.toc),
                      onPressed: _showTableOfContents,
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
