import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
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
  }

  @override
  void dispose() {
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
    final distance = (position.viewportDimension * 0.85)
        .clamp(64.0, double.infinity);
    controller.animateTo(
      (position.pixels + distance).clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _jumpUp() {
    if (!controller.hasClients) return;
    final position = controller.position;
    final distance = (position.viewportDimension * 0.85)
        .clamp(64.0, double.infinity);
    controller.animateTo(
      (position.pixels - distance).clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final paragraphs = widget.sourcedata.paragraphs;
    return NavScaff(
      showNavbar: false,
      child: BindingDispatcher(
        actions: [
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.nextChapter,
            onTrigger: _nextChapter,
          ),
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.prevChapter,
            onTrigger: _prevChapter,
          ),
          BindingAction(
            setting:
                settings.readerSettings.paragraphreader.bindings.toggleBookmark,
            onTrigger: _toggleBookmark,
          ),
          BindingAction(
            setting:
                settings.readerSettings.paragraphreader.bindings.jumpDown,
            onTrigger: _jumpDown,
          ),
          BindingAction(
            setting: settings.readerSettings.paragraphreader.bindings.jumpUp,
            onTrigger: _jumpUp,
          ),
        ],
        child: ReaderSelectable(
          selectionContextItems: (text) => quoteContextItems(
            context,
            widget.source.episode,
            text,
          ),
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
                      context.pop();
                    },
                  ),
                  actions: [
                    DionIconbutton(
                      icon: Icon(
                        epdata.bookmark ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      onPressed: _toggleBookmark,
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
      ),
    );
  }
}
