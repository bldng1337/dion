import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';

import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/selection.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final psettings = settings.readerSettings.paragraphreader;

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
      widget.supplier.preload(widget.supplier.episode.next);
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
    widget.supplier.addListener(() {
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
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.source.episode.save();
    WakelockPlus.toggle(enable: false);
    super.dispose();
  }

  Widget wrapScreen(BuildContext context, Widget child) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        psettings.text.linewidth,
        psettings.text.adaptivewidth,
      ]),
      builder: (context, child) {
        if (psettings.text.adaptivewidth.value &&
            context.width < context.height) {
          return child!;
        }
        final width =
            context.width * (1 - (psettings.text.linewidth.value / 100));
        final padding = width / 2;
        return child!.paddingOnly(left: padding, right: padding);
      },
      child: child,
    );
  }

  Widget wrapParagraph(BuildContext context, Paragraph text) {
    return ListenableBuilder(
      listenable: psettings.text.paragraphspacing,
      builder: (context, child) =>
          child!.paddingOnly(bottom: psettings.text.paragraphspacing.value * 5),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          psettings.text.linespacing,
          psettings.text.size,
          psettings.text.weight,
        ]),
        builder: (context, child) => makeParagraph(context, text),
      ),
    );
  }

  Widget makeParagraph(BuildContext context, Paragraph text) {
    switch (text) {
      case final Paragraph_Text text:
        return Text(
          text.content,
          style: context.bodyLarge?.copyWith(
            height: psettings.text.linespacing.value,
            fontSize: psettings.text.size.value.toDouble(),
            fontWeight: FontWeight.lerp(
              FontWeight.w100,
              FontWeight.w900,
              psettings.text.weight.value,
            ),
          ),
        );
      case Paragraph_CustomUI():
        return ErrorDisplay(
          e: Exception('CustomUI not implemented'),
          message: 'CustomUI not yet implemented',
        ); //TODO: Implement CustomUI
    }
  }

  @override
  Widget build(BuildContext context) {
    final epdata = widget.source.episode.data;
    final paragraphs = widget.sourcedata.paragraphs;
    return NavScaff(
      showNavbar: false,
      child: ListenableBuilder(
        listenable: psettings.text.selectable,
        builder: (context, child) {
          if (psettings.text.selectable.value) {
            return Selection(child: child!);
          }
          return child!;
        },
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
                      ? wrapScreen(
                          context,
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
                  itemBuilder: (context, index) => wrapScreen(
                    context,
                    wrapParagraph(context, paragraphs[index]),
                  ),
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
      ),
    );
  }
}
