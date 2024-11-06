import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:text_scroll/text_scroll.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  late Entry entry;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    entry = GoRouterState.of(context).extra! as Entry;
    if (entry is! EntryDetailed) {
      final ext = locate<SourceExtension>();
      loading = true;
      ext.detail(entry).then((value) {
        entry = value;
        setState(() {});
      }).onError((e, stack) {
        logger.e('Error loading entry', error: e, stackTrace: stack);
      });
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: TextScroll(entry.title),
      ),
      body: Row(
        children: [
          SizedBox(
            width: context.width / 2,
            child: EntryInfo(entry: entry),
          ).expanded(),
          isEntryDetailed(
            entry: entry,
            isdetailed: (entry) => EpisodeListUI(ep: entry.episodes),
          ).expanded(),
        ],
      ),
    );
  }
}

Widget isEntryDetailed({
  required Entry entry,
  required Widget Function(EntryDetailed e) isdetailed,
  Widget Function()? isnt,
  bool shimmer = true,
}) {
  isnt ??= () => Container(
        color: Colors.white,
      );
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(
    child: isnt(),
  ).applyShimmer();
}

class EntryInfo extends StatelessWidget {
  final Entry entry;
  const EntryInfo({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 3, left: 7, right: 7),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DionImage(
              imageUrl: entry.cover,
              width: 130,
              height: 200,
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextScroll(
                  entry.title,
                  style: context.headlineMedium,
                  pauseBetween: 1.seconds,
                ).paddingOnly(bottom: 3),
                TextScroll(
                  entry.author?.reduce((a, b) => '$a • $b') ?? 'Unkown author',
                  style: context.bodyLarge,
                  pauseBetween: 1.seconds,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DionImage(
                      imageUrl: entry.extension.data.icon,
                      width: 20,
                      height: 20,
                      errorWidget: const Icon(
                        Icons.image,
                        size: 20,
                      ),
                    ),
                    TextScroll(
                      entry.extension.data.name,
                      style: context.bodyLarge,
                      pauseBetween: 1.seconds,
                    ),
                    const Text(' • '),
                    isEntryDetailed(
                      entry: entry,
                      isdetailed: (entry) => Text(
                        entry.status.asString(),
                        style: context.bodyLarge,
                      ),
                      isnt: () => Text(
                        'Releasing',
                        style: context.bodyLarge,
                      ),
                    ),
                  ],
                ),
                if (entry.rating != null)
                  Stardisplay(
                    width: 20,
                    height: 20,
                    fill: entry.rating!,
                    color: Colors.yellow[500]!,
                  ),
              ],
            ).paddingAll(5).expanded(),
          ],
        ),
        isEntryDetailed(
          entry: entry,
          isdetailed: (entry) => PlatformIconButton(
            icon: Icon(
              entry.inLibrary ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
            onPressed: () => logger.i('asd'),
          ),
          isnt: () => PlatformIconButton(
            icon: Icon(
              entry.inLibrary ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
          ),
          shimmer: false,
        ),
        SizedBox(
          height: 40,
          child: isEntryDetailed(
            entry: entry,
            isdetailed: (entry) => ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: entry.genres
                      ?.map(
                        (e) => DionBadge(
                          child: Text(e),
                        ),
                      )
                      .toList() ??
                  [],
            ),
            isnt: () => Row(
              children: getWords(4)
                  .map(
                    (e) => DionBadge(
                      child: Text(e),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        isEntryDetailed(
          entry: entry,
          isdetailed: (entry) => Foldabletext(
            maxLines: 7,
            entry.description.trim(),
            style: context.bodyMedium,
          ),
          isnt: () => Text(
            maxLines: 7,
            getText(70),
            style: context.bodyMedium,
          ),
        ).paddingOnly(top: 7),
      ],
    );
  }
}

class EpisodeListUI extends StatelessWidget {
  final List<EpisodeList> ep;
  const EpisodeListUI({super.key, required this.ep});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class CustomUI extends StatelessWidget {
  const CustomUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
