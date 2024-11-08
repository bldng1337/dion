import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
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
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:text_scroll/text_scroll.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> with StateDisposeScopeMixin {
  Entry? entry;
  bool loading = false;
  late CancelToken tok;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (entry == null) {
      logger.i('didchangedep');
      entry = GoRouterState.of(context).extra! as Entry;
      if (entry is! EntryDetailed && mounted) {
        logger.i('loading entry');
        final ext = locate<SourceExtension>();
        loading = true;
        ext.detail(entry!, token: tok).then((value) {
          if (mounted) {
            setState(() {
              entry = value;
            });
          }
        }).onError((e, stack) {
          logger.e('Error loading entry', error: e, stackTrace: stack);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    tok = CancelToken()..disposedBy(scope);
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
            isdetailed: (entry) => EpisodeListUI(
              entry: entry,
            ),
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
  final EntryDetailed entry;
  const EpisodeListUI({super.key, required this.entry});

  @override
  State<EpisodeListUI> createState() => _EpisodeListUIState();
}

class _EpisodeListUIState extends State<EpisodeListUI> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final eplist = widget.entry.episodes;
    if (eplist.isEmpty) {
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
              options: eplist.indexed
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
              '${eplist[selected].title} - ${eplist[selected].episodes.length} Episodes',
              style: context.labelSmall,
            ),
          ],
        ),
        EpList(entry: widget.entry, eplistindex: selected).expanded(),
      ],
    );
  }
}

class EpList extends StatelessWidget {
  final EntryDetailed entry;
  final int eplistindex;
  EpisodeList get elist => entry.episodes[eplistindex];
  const EpList({super.key, required this.entry, required this.eplistindex});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: elist.episodes.length,
      itemBuilder: (BuildContext context, int index) =>
          EpisodeTile(episodepath: EpisodePath(entry, eplistindex, index)),
    );
  }
}

class EpisodeTile extends StatelessWidget {
  final EpisodePath episodepath;
  const EpisodeTile({super.key, required this.episodepath});

  @override
  Widget build(BuildContext context) {
    return PlatformListTile(
      onTap: () => GoRouter.of(context).push('/view', extra: episodepath),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DionImage(
            imageUrl: episodepath.episode.cover,
            width: 90,
            height: 60,
            boxFit: BoxFit.contain,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episodepath.episode.name,
                style: context.titleMedium,
              ),
              if (episodepath.episode.timestamp != null)
                Text(
                  DateTime.tryParse(episodepath.episode.timestamp!)
                          ?.formatrelative() ??
                      '',
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
