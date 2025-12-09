import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';

import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/selection.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';

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
  late final ScrollController controller;

  void onScroll() {
    final epdata = widget.source.episode.data;
    if (epdata.finished) return;
    if (controller.offset > 0 && controller.position.atEdge) {
      if (epdata.finished) return;
      epdata.finished = true;
      widget.source.episode.save();
      return;
    }
    if (controller.offset >= controller.position.maxScrollExtent / 2) {
      widget.supplier.cache.preload(widget.supplier.episode.next);
    }
    epdata.progress = controller.offset.toString();
  }

  @override
  void initState() {
    WakelockPlus.toggle(enable: true);
    final epdata = widget.source.episode.data;
    controller = ScrollController(
      initialScrollOffset: epdata.finished
          ? 0
          : double.tryParse(epdata.progress ?? '0') ?? 0,
    )..disposedBy(scope);
    controller.addListener(onScroll);
    Observer(() {
      if (!controller.hasClients) {
        return;
      }
      // Listener gets detached when loading a new page not sure why
      controller.removeListener(onScroll);
      controller.addListener(onScroll);
      final epdata = widget.source.episode.data;
      final double pos = epdata.finished
          ? 0
          : double.tryParse(epdata.progress ?? '0') ?? 0;
      Future.microtask(() => controller.jumpTo(pos));
    }, widget.supplier).disposedBy(scope);
    super.initState();
  }

  @override
  void dispose() {
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final paragraphs = widget.sourcedata.paragraphs;
    return NavScaff(
      showNavbar: false,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverAppBar(
              floating: true,
              title: DionTextScroll(widget.source.name),
              actions: [
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
                  child: const Text('Previous'),
                  onPressed: () =>
                      widget.source.episode.goPrev(widget.supplier),
                ).paddingSymmetric(vertical: 32),
              ),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: psettings.title,
                builder: (context, child) => psettings.title.value
                    ? ReaderWrapScreen(
                        Text(
                          widget.source.name,
                          style: context.headlineMedium,
                          textAlign: TextAlign.center,
                        ).paddingSymmetric(vertical: 16),
                      )
                    : nil,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              sliver: SliverList.builder(
                itemBuilder: (context, index) =>
                    ReaderWrapScreen(ReaderRenderParagraph(paragraphs[index])),
                itemCount: paragraphs.length,
              ),
            ),
            if (widget.source.episode.hasnext)
              SliverToBoxAdapter(
                child: DionTextbutton(
                  child: const Text('Next'),
                  onPressed: () =>
                      widget.source.episode.goNext(widget.supplier),
                ).paddingSymmetric(vertical: 32),
              ),
          ],
        ),
      ),
    );
  }
}
