import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
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
  Entry? entry;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    entry ??= GoRouterState.of(context).extra! as Entry;
    if (entry is! EntryDetailed) {
      final ext = locate<SourceExtension>();
      loading = true;
      ext.detail(entry!).then((value) {
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
        title: TextScroll(entry?.title ?? ''),
      ),
      body: Row(
        children: [
          SizedBox(
            width: context.width / 2,
            child: EntryInfo(entry: entry!),
          ).expanded(),
          isEntryDetailed(
            entry: entry!,
            isdetailed: (entry) => EpisodeListUI(eplist: entry.episodes),
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

class EpisodeListUI extends StatefulWidget {
  final List<EpisodeList> eplist;
  const EpisodeListUI({super.key, required this.eplist});

  @override
  State<EpisodeListUI> createState() => _EpisodeListUIState();
}

class _EpisodeListUIState extends State<EpisodeListUI> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.eplist.isEmpty) {
      return Center(
        child: Text(
          'No Episodes',
          style: context.labelLarge,
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            PlatformPopupMenu(
              options: widget.eplist.indexed
                  .map(
                    (ep) => PopupMenuOption(
                      label: '${ep.$2.title} - ${ep.$2.episodes.length}',
                      onTap: (menu) => setState(() {
                        selected = ep.$1;
                      }),
                    ),
                  )
                  .toList(),
              icon: const Icon(Icons.folder),
            ),
            Text(
              '${widget.eplist[selected].title} - ${widget.eplist[selected].episodes.length} Episodes',
              style: context.labelSmall,
            ),
          ],
        ),
        EpList(elist: widget.eplist[selected]).expanded(),
      ],
    );
  }
}

class EpList extends StatelessWidget {
  final EpisodeList elist;
  const EpList({super.key, required this.elist});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: elist.episodes.length,
      itemBuilder: (BuildContext context, int index) =>
          EpisodeTile(e: elist.episodes[index]),
    );
  }
}

class EpisodeTile extends StatelessWidget {
  final Episode e;
  const EpisodeTile({super.key, required this.e});

  @override
  Widget build(BuildContext context) {
    logger.i(DateTime.tryParse(e.timestamp!));
    return PlatformListTile(
      onTap: () => logger.i('Tapped'),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DionImage(
            imageUrl: e.cover,
            width: 90,
            height: 60,
            boxFit: BoxFit.contain,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: context.titleMedium,
              ),
              if (e.timestamp != null)
                Text(
                  DateTime.tryParse(e.timestamp!)?.formatrelative() ?? '',
                  style: context.labelSmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomUI extends StatelessWidget {
  const CustomUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
