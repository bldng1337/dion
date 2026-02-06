import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/views/view/paragraphlist/tts_controller.dart';
import 'package:dionysos/views/view/session.dart';
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
  late final TtsController ttsController;

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
  }

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

  void _onTtsChanged() {
    if (!mounted) return;
    setState(() {});
    // Auto-scroll to the paragraph currently being spoken
    if (ttsController.state == TtsState.playing &&
        ttsController.currentParagraphIndex >= 0 &&
        listController.isAttached &&
        controller.hasClients) {
      listController.animateToItem(
        index: ttsController.currentParagraphIndex,
        scrollController: controller,
        alignment: 0.3,
        duration: (double estimatedDistance) =>
            const Duration(milliseconds: 300),
        curve: (double estimatedDistance) => Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    WakelockPlus.toggle(enable: true);
    controller = ScrollController(onAttach: (position) => jumpToProgress())
      ..disposedBy(scope);

    listController = ListController()..disposedBy(scope);
    listController.addListener(onScroll);

    ttsController = TtsController()..disposedBy(scope);
    ttsController.loadParagraphs(widget.sourcedata.paragraphs);
    ttsController.onChapterEnd = () {
      if (widget.source.episode.hasnext) {
        widget.source.episode.goNext(widget.supplier);
      }
    };
    ttsController.addListener(_onTtsChanged);

    supplierObserver = Observer(jumpToProgress, widget.supplier)
      ..disposedBy(scope);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    supplierObserver.swapListener(widget.supplier);
  }

  @override
  void dispose() {
    ttsController.removeListener(_onTtsChanged);
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final paragraphs = widget.sourcedata.paragraphs;
    return TtsStateData(
      controller: ttsController,
      child: NavScaff(
        showNavbar: false,
        child: ScrollConfiguration(
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
                    ttsController.stop();
                    context.pop();
                  },
                ),
                actions: [
                  DionIconbutton(
                    icon: Icon(switch (ttsController.state) {
                      TtsState.playing => Icons.pause,
                      TtsState.paused => Icons.play_arrow,
                      TtsState.stopped => Icons.volume_up,
                    }),
                    onPressed: () => ttsController.togglePlayPause(
                      fromParagraph:
                          listController.unobstructedVisibleRange?.$1,
                    ),
                  ),
                  if (ttsController.state != TtsState.stopped)
                    DionIconbutton(
                      icon: const Icon(Icons.stop),
                      onPressed: () => ttsController.stop(),
                    ),
                  DionIconbutton(
                    icon: Icon(
                      epdata.bookmark ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: () async {
                      epdata.bookmark = !epdata.bookmark;
                      await widget.source.episode.save();
                      if (mounted) {
                        setState(() {});
                      }
                    },
                  ),
                  DionIconbutton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () =>
                        launchUrl(Uri.parse(widget.source.episode.episode.url)),
                  ),
                  DionIconbutton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => context.push('/settings/paragraphreader'),
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
                  itemBuilder: (context, index) => ReaderWrapScreen(
                    ReaderRenderParagraph(
                      paragraphs[index],
                      widget.supplier.episode.entry.extension!,
                      paragraphIndex: index,
                    ),
                  ),
                  itemCount: paragraphs.length,
                ),
              ),
              if (widget.source.episode.hasnext)
                SliverToBoxAdapter(
                  child: DionTextbutton(
                    child: const Text('Next').paddingSymmetric(vertical: 16),
                    onPressed: () =>
                        widget.source.episode.goNext(widget.supplier),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
