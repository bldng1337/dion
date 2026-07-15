import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/views/view/paragraphlist/tts_controller.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/widgets/binding_dispatcher.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SimpleParagraphlistReader extends StatefulWidget {
  final SourcePath source;
  final SourceSupplier supplier;
  Source_Paragraphlist get sourcedata => source.source as Source_Paragraphlist;
  const SimpleParagraphlistReader({
    super.key,
    required this.source,
    required this.supplier,
  });

  @override
  _SimpleParagraphlistReaderState createState() =>
      _SimpleParagraphlistReaderState();
}

class _SimpleParagraphlistReaderState extends State<SimpleParagraphlistReader>
    with StateDisposeScopeMixin {
  late final ListController listController;
  late final Observer supplierObserver;
  late final ScrollController controller;

  TtsController? _tts;

  void onScroll() {
    final epdata = widget.source.episode.data;
    SessionData.of(context)?.manager.keepSessionAlive();
    if (controller.hasClients &&
        controller.offset > 0 &&
        controller.position.atEdge) {
      if (epdata.finished) return;
      epdata.finished = true;
      widget.source.episode.save();
      return;
    }
    if (listController.isAttached) {
      final position = listController.unobstructedVisibleRange?.$1;

      if ((listController.visibleRange?.$2 ?? 0) >=
          listController.numberOfItems / 2) {
        widget.supplier.cache.preload(widget.supplier.episode.next);
      }
      if (position != null && position != 0) {
        widget.source.episode.data.progress = position.toString();
      }
    }
    if (lastscrollOffset < controller.offset - 500) {
      SessionData.of(context)?.manager.keepSessionAlive(saveToDb: true);
      lastscrollOffset = controller.offset.toInt();
    }
  }

  int lastscrollOffset = 0;

  void jumpToProgress() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!listController.isAttached || !controller.hasClients) {
        return;
      }
      final epdata = widget.source.episode.data;
      final int pos = epdata.finished
          ? 0
          : int.tryParse(epdata.progress ?? '0') ?? 0;
      if (pos == 0) return;
      listController.jumpToItem(
        index: pos,
        alignment: 0.0,
        scrollController: controller,
      );
    });
  }

  void _followTts() {
    if (!listController.isAttached || !controller.hasClients) return;
    final tts = _tts;
    if (tts == null) return;
    final index = tts.currentParagraphIndex;
    if (index < 0) return;
    final range = listController.visibleRange;
    if (range != null && index >= range.$1 && index <= range.$2) return;
    listController.animateToItem(
      index: index,
      alignment: 0.0,
      scrollController: controller,
      duration: (estimatedDistance) => Duration(
        milliseconds: (200 + (estimatedDistance / 5).clamp(0, 300)).round(),
      ),
      curve: (estimatedDistance) => Curves.easeOut,
    );
  }

  @override
  void initState() {
    WakelockPlus.toggle(enable: true);
    controller = ScrollController(onAttach: (position) => jumpToProgress())
      ..disposedBy(scope);

    listController = ListController()..disposedBy(scope);
    listController.addListener(onScroll);

    supplierObserver = Observer(jumpToProgress, widget.supplier)
      ..disposedBy(scope);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    supplierObserver.swapListener(widget.supplier);
    _attachTts();
  }

  void _attachTts() {
    final tts = TtsStateData.of(context);
    if (tts == null) return;
    _tts = tts;
    tts.removeListener(_followTts);
    tts.addListener(_followTts);
    if (tts.state == TtsState.stopped) {
      tts.loadParagraphs(
        widget.sourcedata.paragraphs,
        hasNextChapter: widget.source.episode.hasnext,
        mediaInfo: ttsMediaInfoFor(widget.source.episode),
      );
    } else {
      tts.setMediaInfo(ttsMediaInfoFor(widget.source.episode));
    }
  }

  @override
  void dispose() {
    _tts?.removeListener(_followTts);
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    super.dispose();
  }

  void _nextChapter() {
    if (!widget.source.episode.hasnext) return;
    widget.source.episode.goNext(widget.supplier);
  }

  void _prevChapter() {
    if (!widget.source.episode.hasprev) return;
    widget.source.episode.goPrev(widget.supplier);
  }

  Future<void> _toggleBookmark() async {
    final epdata = widget.source.episode.data;
    epdata.bookmark = !epdata.bookmark;
    await widget.source.episode.save();
    if (mounted) {
      setState(() {});
    }
  }

  void _jumpDown() {
    if (!controller.hasClients) return;
    final position = controller.position;
    final distance = (position.viewportDimension * 0.85).clamp(
      64.0,
      double.infinity,
    );
    controller.animateTo(
      (position.pixels + distance).clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _jumpUp() {
    if (!controller.hasClients) return;
    final position = controller.position;
    final distance = (position.viewportDimension * 0.85).clamp(
      64.0,
      double.infinity,
    );
    controller.animateTo(
      (position.pixels - distance).clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _toggleTts() {
    final fromParagraph = listController.isAttached
        ? listController.unobstructedVisibleRange?.$1
        : null;
    _tts?.togglePlayPause(fromParagraph: fromParagraph);
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final paragraphs = widget.sourcedata.paragraphs;
    final tts = _tts;
    return NavScaff(
      showNavbar: false,
      child: BindingDispatcher(
        actions: [
          BindingAction(
            setting:
                settings.readerSettings.paragraphreader.bindings.nextChapter,
            onTrigger: _nextChapter,
          ),
          BindingAction(
            setting:
                settings.readerSettings.paragraphreader.bindings.prevChapter,
            onTrigger: _prevChapter,
          ),
          BindingAction(
            setting:
                settings.readerSettings.paragraphreader.bindings.toggleBookmark,
            onTrigger: _toggleBookmark,
          ),
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.jumpDown,
            onTrigger: _jumpDown,
          ),
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.jumpUp,
            onTrigger: _jumpUp,
          ),
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.toggleTts,
            onTrigger: _toggleTts,
          ),
        ],
        child: ReaderSelectable(
          selectionContextItems: (text) =>
              quoteContextItems(context, widget.source.episode, text),
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(),
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      title: DionTextScroll(widget.source.name),
                      leading: DionIconbutton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          context.pop();
                        },
                      ),
                      actions: [
                        if (tts != null)
                          ListenableBuilder(
                            listenable: tts,
                            builder: (context, _) {
                              return DionIconbutton(
                                tooltip: 'Read aloud',
                                icon: Icon(
                                  tts.state == TtsState.playing
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                ),
                                onPressed: _toggleTts,
                              );
                            },
                          ),
                        DionIconbutton(
                          icon: Icon(
                            epdata.bookmark
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          onPressed: _toggleBookmark,
                        ),
                        DionIconbutton(
                          icon: const Icon(Icons.open_in_browser),
                          onPressed: () => launchUrl(
                            Uri.parse(widget.source.episode.episode.url),
                          ),
                        ),
                        DionIconbutton(
                          icon: const Icon(Icons.settings),
                          onPressed: () =>
                              context.push('/settings/paragraphreader'),
                        ),
                      ],
                    ),
                    if (widget.source.episode.hasprev)
                      SliverToBoxAdapter(
                        child: DionTextbutton(
                          child: const Text(
                            'Previous',
                          ).paddingSymmetric(vertical: 16),
                          onPressed: () =>
                              widget.source.episode.goPrev(widget.supplier),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: EpisodeTitle(episode: widget.source.episode),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      sliver: SuperSliverList.builder(
                        listController: listController,
                        itemBuilder: (context, index) =>
                            _buildParagraphItem(context, index, paragraphs),
                        itemCount: paragraphs.length,
                      ),
                    ),
                    if (widget.source.episode.hasnext)
                      SliverToBoxAdapter(
                        child: DionTextbutton(
                          child: const Text(
                            'Next',
                          ).paddingSymmetric(vertical: 16),
                          onPressed: () =>
                              widget.source.episode.goNext(widget.supplier),
                        ),
                      ),
                    // Space so the last paragraph isn't hidden behind the popup.
                    if (tts != null &&
                        tts.state != TtsState.stopped &&
                        !tts.isLoadingNextChapter)
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              ),
              if (tts != null)
                Positioned(
                  left: DionSpacing.sm,
                  right: DionSpacing.sm,
                  bottom: DionSpacing.sm,
                  child: TtsPlayerBar(tts: tts),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraphItem(
    BuildContext context,
    int index,
    List<Paragraph> paragraphs,
  ) {
    final tts = _tts;
    final paragraph = ReaderWrapScreen(
      ReaderRenderParagraph(
        paragraphs[index],
        widget.supplier.episode.entry.extension!,
      ),
    );
    if (tts == null) return paragraph;
    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        final narrating = tts.state != TtsState.stopped;
        final active = narrating && index == tts.currentParagraphIndex;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DionRadius.sm),
          ),
          child: paragraph,
        );
      },
    );
  }
}

class TtsPlayerBar extends StatelessWidget {
  final TtsController tts;
  const TtsPlayerBar({super.key, required this.tts});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        if (tts.state == TtsState.stopped) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final playing = tts.state == TtsState.playing;
        final loading = tts.isLoadingNextChapter;
        final segmentCount = tts.segmentCount;
        final progress = segmentCount > 0
            ? (tts.segmentIndex + 1) / segmentCount
            : 0.0;

        return SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(DionRadius.xl),
            color: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DionSpacing.md,
                vertical: DionSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loading ? 'Loading next chapter…' : 'Read aloud',
                          style: DionTypography.titleSmall(
                            theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DionIconbutton(
                        tooltip: 'Previous paragraph',
                        icon: const Icon(Icons.skip_previous, size: 22),
                        onPressed: loading
                            ? null
                            : () => tts.skipToPreviousParagraph(),
                      ),
                      DionIconbutton(
                        tooltip: playing ? 'Pause' : 'Play',
                        icon: loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 28,
                              ),
                        onPressed: loading
                            ? null
                            : () {
                                if (playing) {
                                  tts.pause();
                                } else {
                                  tts.resume();
                                }
                              },
                      ),
                      DionIconbutton(
                        tooltip: 'Next paragraph',
                        icon: const Icon(Icons.skip_next, size: 22),
                        onPressed: loading
                            ? null
                            : () => tts.skipToNextParagraph(),
                      ),
                      DionIconbutton(
                        tooltip: 'Stop',
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => tts.stop(),
                      ),
                    ],
                  ),
                  if (!loading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DionRadius.xs),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
