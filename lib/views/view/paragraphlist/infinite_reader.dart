import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/widgets/large_list.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:dionysos/views/view/paragraphlist/reader.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class InfiniteParagraphListReader extends StatefulWidget {
  final SourceSupplier supplier;
  const InfiniteParagraphListReader({super.key, required this.supplier});

  @override
  State<InfiniteParagraphListReader> createState() =>
      _InfiniteParagraphListReaderState();
}

class _InfiniteParagraphListReaderState
    extends State<InfiniteParagraphListReader>
    with StateDisposeScopeMixin {
  bool loading = true;
  @override
  void initState() {
    WakelockPlus.toggle(enable: true);
    widget.supplier.cache.get(widget.supplier.episode).then((_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.supplier.episode.save();
    WakelockPlus.toggle(enable: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const NavScaff(
        title: Text('Loading'),
        child: Center(child: DionProgressBar()),
      );
    }
    return NavScaff(
      title: ListenableBuilder(
        listenable: widget.supplier,
        builder: (context, child) =>
            DionTextScroll(widget.supplier.episode.name),
      ),
      actions: [
        DionIconbutton(
          icon: Icon(
            widget.supplier.episode.data.bookmark
                ? Icons.bookmark
                : Icons.bookmark_border,
          ),
          onPressed: () async {
            widget.supplier.episode.data.bookmark =
                !widget.supplier.episode.data.bookmark;
            await widget.supplier.episode.save();
            if (mounted) {
              setState(() {});
            }
          },
        ),
        DionIconbutton(
          icon: const Icon(Icons.open_in_browser),
          onPressed: () =>
              launchUrl(Uri.parse(widget.supplier.episode.episode.url)),
        ),
        DionIconbutton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings/paragraphreader'),
        ),
      ],
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: HugeListView(
          firstShown: (value) {
            if (value == widget.supplier.episode.episodenumber) return;
            widget.supplier.setEpisodeByIndex(value);
          },
          totalCount: widget.supplier.episode.entry.episodes.length,
          startIndex: widget.supplier.episode.episodenumber,
          pageFuture: (int pageIndex) async {
            return await widget.supplier.getIndex(pageIndex);
          },
          itemBuilder: (BuildContext context, int index, dynamic test) {
            final sourcepath = test as SourcePath;
            final source = sourcepath.source as Source_Paragraphlist;
            return ListenableBuilder(
              listenable: settings.readerSettings.paragraphreader.title,
              builder: (context, child) {
                if (!settings.readerSettings.paragraphreader.title.value) {
                  return child!;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EpisodeTitle(episode: sourcepath.episode),
                    child!,
                  ],
                );
              },
              child: ReaderWrapScreen(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: source.paragraphs
                      .map((e) => ReaderRenderParagraph(e))
                      .toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
