import 'dart:convert';
import 'dart:math';

import 'package:dionysos/Source.dart';
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/sync.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/views/entrybrowseview.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DownloadButton extends StatelessWidget {
  final EntrySaved entry;
  final AEpisodeList list;
  final int episode;

  const DownloadButton(this.entry, this.list, this.episode, {super.key});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => FutureLoader(
        entry.isDownloaded(list, episode),
        success: (context, isDownloaded) => isDownloaded
            ? IconButton(
                onPressed: () {
                  entry.delete(list, episode).then((value) {
                    if (context.mounted) {
                      setState(
                        () {},
                      );
                    }
                  });
                },
                icon: const Icon(Icons.download_done),
              )
            : FutureLoader(
                entry.getDownloads(list, episode),
                success: (context, downloadTasks) {
                  if (downloadTasks.isNotEmpty) {
                    return const CircularProgressIndicator();
                  }
                  return IconButton(
                    onPressed: () {
                      entry.download(list, episode).then((value) {
                        if (context.mounted) {
                          setState(
                            () {},
                          );
                        }
                      });
                    },
                    icon: const Icon(Icons.download),
                  );
                },
              ),
      ),
    );
  }
}

class EntryDetailedView extends StatefulWidget {
  const EntryDetailedView({super.key});

  @override
  State<EntryDetailedView> createState() => _EntryDetailedViewState();
}

class _EntryDetailedViewState extends State<EntryDetailedView> {
  Future<EntryDetail?>? _entry;
  int episodeindex = 0;
  AEpisodeList? eplist;
  Set<int> selected = {};
  ScrollPhysics scrollPhysics = const ClampingScrollPhysics();
  ScrollController episodescrollController = ScrollController();
  ScrollController scrollController = ScrollController();
  bool refreshing = false;
  @override
  void initState() {
    super.initState();

    scrollController.addListener(onScroll);
    episodescrollController.addListener(onScroll);
  }

  void onScroll() {
    if (!scrollController.hasClients || !episodescrollController.hasClients) {
      return;
    }
    setState(() {});
    scrollPhysics = const NeverScrollableScrollPhysics();
    if (scrollController.offset != scrollController.position.maxScrollExtent) {
      return;
    }
    if (episodescrollController.offset != 0.0) {
      scrollPhysics = const ClampingScrollPhysics();
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      episodescrollController.jumpTo(episodescrollController.offset + 1);
      scrollPhysics = const ClampingScrollPhysics();
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget buildEpisodes(EntryDetail entry, BuildContext context) {
    final List<int> ceplist = eplist!.episodes.indexed
        // .where((element) => entry.getEpdata(element.$1).isBookmarked)
        .map((e) => e.$1)
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${ceplist.length} Episodes'),
          PopupMenuButton<dynamic>(
            itemBuilder: (BuildContext context) => [
              ...entry.episodes.indexed.map(
                (e) => PopupMenuItem(
                  value: e.$1,
                  child: Row(
                    children: [
                      Text(e.$2.title),
                      const Spacer(),
                      Text('${e.$2.episodes.length}'),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
            ],
            onSelected: (value) {
              if (value == null) {
                return;
              }
              if (value is int) {
                setState(
                  () {
                    selected.clear();
                    eplist = entry.episodes[value];
                    entry.episodeindex = value;
                    entry.save();
                  },
                );
                return;
              }
            },
            // icon: const Icon(Icons.source),
            tooltip: 'Choose Source',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.source),
                Text("Sources - ${eplist?.title ?? "Unknown"}"),
              ],
            ),
          ),
          // DropdownMenu<int>(
          //   dropdownMenuEntries: entry.episodes.indexed
          //       .map((e) => DropdownMenuEntry(label: e.$2.title, value: e.$1))
          //       .toList(),
          //   enableSearch: false,
          //   requestFocusOnTap: false,
          //   initialSelection: episodeindex,
          //   onSelected: (i) {
          //     setState(() {
          //       episodeindex = i ?? episodeindex;
          //     });
          //   },
          // ),
          if (eplist != null)
            Expanded(
              child: ListView.builder(
                controller: episodescrollController,
                physics: scrollPhysics,
                shrinkWrap: isVertical(context),
                itemCount: ceplist.length,
                itemBuilder: (context, cindex) {
                  final int index = ceplist[cindex];
                  final ep = eplist!.getEpisode(index);
                  return ListTile(
                    isThreeLine: true,
                    contentPadding: const EdgeInsets.all(5),
                    titleAlignment: ListTileTitleAlignment.center,
                    minVerticalPadding: 2,
                    leading: ep?.thumbnail != null
                        ? FancyShimmerImage(
                            imageUrl: ep?.thumbnail ?? 'https://0.0.0.0/',
                            httpHeaders: (json.decode(ep?.thumbheader ?? '{}')
                                    as Map<String, dynamic>)
                                .cast(),
                            boxFit: BoxFit.contain,
                            width: 88,
                            height: 88,
                          )
                        : null,
                    selected: selected.contains(index),
                    onTap: () {
                      if (selected.isNotEmpty) {
                        setState(() {
                          if (selected.contains(index)) {
                            selected.remove(index);
                          } else {
                            selected.add(index);
                          }
                        });
                        return;
                      }
                      if (ep != null) {
                        navSource(context, entry.source(eplist!, index));
                      }
                    },
                    hoverColor: Theme.of(context).hoverColor,
                    title: Row(
                      children: [
                        if (entry.getEpdata(index).isBookmarked)
                          const Padding(
                            padding: EdgeInsets.only(right: 1, top: 3),
                            child: Icon(
                              Icons.bookmark,
                              size: 15,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            ep?.name ?? 'Unknown',
                            maxLines: 1,
                          ),
                        ),
                        if (entry is EntrySaved)
                          DownloadButton(entry, eplist!, index),
                      ],
                    ),
                    onLongPress: () {
                      setState(() {
                        if (selected.contains(index)) {
                          selected.remove(index);
                        } else {
                          selected.add(index);
                        }
                      });
                    },
                    textColor: entry.getEpdata(index).completed
                        ? Theme.of(context).disabledColor
                        : null,
                    subtitle: Row(
                      children: [
                        Text('Chapter ${index + 1}'),
                        if (ep?.timestamp != null)
                          Text(
                            ' - ${DateFormat.yMMMd().format(ep!.timestamp!)}',
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget buttonbar(EntryDetail entry, BuildContext context) {
    final bool isinLibrary = entry is EntrySaved;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(isinLibrary ? Icons.book : Icons.book_outlined),
          tooltip: isinLibrary ? 'Remove from Library' : 'Add to Library',
          onPressed: () async {
            if (isinLibrary) {
              setState(() {
                _entry = entry.toEntryDetailed();
              });
              await isar.writeTxn(() async {
                await isar.entrySaveds.delete(entry.id);
              });
              savesync();
            } else {
              final EntrySaved newentry = EntrySaved.fromEntry(entry);
              await isar.writeTxn(() async {
                isar.entrySaveds.put(newentry);
              });
              savesync();
              setState(() {
                _entry = Future.value(newentry);
              });
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: () => share('${entry.title}: ${entry.url}'),
        ),
        if (isinLibrary)
          IconButton(
            tooltip: 'In Construction',
            icon: const Icon(Icons.hourglass_empty),
            onPressed: () => {},
          ),
      ],
    );
  }

  Widget getExtensionWarning(EntryDetail entry, BuildContext context) {
    if (entry.ext == null) {
      return Container(
        padding: const EdgeInsets.all(3),
        color: Colors.red[300],
        child: Row(
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).indicatorColor,
            ),
            Expanded(
              child: Text(
                'Extension for this Entry cant be found',
                style: TextStyle(color: Theme.of(context).indicatorColor),
              ),
            ),
          ],
        ),
      );
    }
    if (!entry.ext!.enabled) {
      return Container(
        padding: const EdgeInsets.all(3),
        color: Colors.red[300],
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.warning,
                color: Theme.of(context).indicatorColor,
              ),
            ),
            Expanded(
              child: Text(
                'Extension for this Entry is disabled',
                style: TextStyle(color: Theme.of(context).indicatorColor),
              ),
            ),
            TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red[300]),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                onPressed: () {
                  entry.ext!.setenabled(true);
                  setState(() {});
                },
                child: const Text('Enable'))
          ],
        ),
      );
    }
    return Container();
  }

  Widget buildDescription(EntryDetail entry, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        getExtensionWarning(entry, context),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                child: FancyShimmerImage(
                  boxDecoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(offset: Offset(0.5, 0.9), blurRadius: 3.0),
                    ],
                  ),
                  width: 130,
                  height: 200,
                  boxFit: BoxFit.contain,
                  imageUrl: entry.cover ?? 'https://0.0.0.0/',
                  httpHeaders: (json.decode(entry.coverheader ?? '{}')
                          as Map<String, dynamic>)
                      .cast(),
                  cacheKey: entry.cover ?? '',
                  errorWidget: const Icon(Icons.image, size: 130),
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    iconColor: Colors.transparent,
                    content: FancyShimmerImage(
                      height: double.maxFinite,
                      width: double.maxFinite,
                      boxFit: BoxFit.contain,
                      imageUrl: entry.cover ?? 'https://0.0.0.0/',
                      errorWidget: const Icon(Icons.image, size: 130),
                      imageBuilder: (context, imageProvider) => GestureDetector(
                        onLongPress: () =>
                            launchUrl(Uri.parse(entry.cover ?? '')),
                        onDoubleTap: () =>
                            launchUrl(Uri.parse(entry.cover ?? '')),
                        onTap: () => Navigator.of(context).pop(),
                        child: Image(
                          image: imageProvider,
                          filterQuality: FilterQuality.high,
                          height: MediaQuery.of(context).size.height * 0.8,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.tight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, top: 35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maxLines: 4,
                        entry.title,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 20.0,
                        ),
                      ),
                      if (entry.author != null && entry.author!.isNotEmpty)
                        Text(
                          maxLines: 1,
                          entry.author!.join(' • '),
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                      Row(
                        children: [
                          FancyShimmerImage(
                            imageUrl:
                                entry.ext?.data?.icon ?? 'https://0.0.0.0/',
                            cacheKey: entry.ext?.data?.icon ?? '',
                            width: 16,
                            height: 16,
                          ),
                          Text(
                            maxLines: 1,
                            "${entry.ext?.data?.name ?? "Unkown"} • ${entry.status.name}",
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              fontSize: 16.0,
                            ),
                          ),
                        ],
                      ),
                      if (entry.views != null)
                        Text(
                          maxLines: 1,
                          '${formatNumber(entry.views!)} Views',
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                        ),
                      if (entry.rating != null)
                        Stardisplay(
                          color: Colors.yellow[300]!,
                          width: 16,
                          height: 16,
                          fill: entry.rating!,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Text(entry.extradata ?? ''),
        buttonbar(entry, context),
        buildUI(json.decode(entry.extradata ?? '[]'), context, entry.ext),
        SizedBox(
          height: 40,
          child: ListView(
            physics: isVertical(context) ? const ClampingScrollPhysics() : null,
            scrollDirection: Axis.horizontal,
            children: entry.genres
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.all(5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Text(
                          e,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Text(
          entry.description ?? '',
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 16.0,
          ),
        ),
      ],
    );
  }

  Widget buildUI(dynamic data, BuildContext context, Extension? extension) {
    try {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: (data as List<dynamic>)
            .map((e) => buildWidget(e, context, extension))
            .toList(),
      );
    } catch (e) {
      debugPrint(e.toString());
      return Container();
    }
  }

  Size getSize(dynamic data, BuildContext context, Extension? extension) {
    switch (data['type']) {
      case 'text':
        return getTextSize(
            data['text'] as String, const TextStyle(fontSize: 14));
      case 'image':
        return const Size(100, 100);
      case 'link':
        return getTextSize(
            data['text'] as String, const TextStyle(fontSize: 14));
      case 'column':
        final sizes = (data['children'] as List<dynamic>)
            .map((e) => getSize(e, context, extension))
            .toList();
        return Size(
            sizes
                .map((a) => a.width)
                .reduce((value, element) => max(value, element)),
            sizes
                .map((a) => a.height)
                .reduce((value, element) => value + element));
      case 'row':
        final sizes = (data['children'] as List<dynamic>)
            .map((e) => getSize(e, context, extension))
            .toList();
        return Size(
            sizes
                .map((a) => a.width)
                .reduce((value, element) => value + element),
            sizes
                .map((a) => a.height)
                .reduce((value, element) => max(value, element)));
      case 'timestamp':
        return getTextSize(
          durationToRelativeTime(
            DateTime.tryParse(data['timestamp'] as String)
                    ?.difference(DateTime.now()) ??
                Duration.zero,
          ),
          const TextStyle(fontSize: 14),
        );
      case 'entrycard':
        return const Size(300 / 1.5, 600 / 2);
    }
    return getTextSize(
      "Something ${data['type']}",
      const TextStyle(fontSize: 14),
    );
  }

  Widget buildWidget(dynamic data, BuildContext context, Extension? extension) {
    switch (data['type']) {
      case 'text':
        return Text(
          data['text'] as String,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.clip,
        );
      case 'image':
        return FancyShimmerImage(
          width: 100,
          height: 100,
          imageUrl: data['image'] as String,
          boxFit: BoxFit.contain,
        );
      case 'link':
        return TextButton(
          onPressed: () {
            launchUrl(Uri.parse(data['link'] as String));
          },
          child: Text(data['text'] as String),
        );
      case 'column':
        final childsize = getSize(data, context, extension);
        return SizedBox(
          width: childsize.width + 5,
          child: ListView(
            shrinkWrap: true,
            children: (data['children'] as List<dynamic>)
                .map((e) => buildWidget(e, context, extension))
                .toList(),
          ),
        );
      case 'row':
        final childsize = getSize(data, context, extension);
        return SizedBox(
          height: childsize.height + 5,
          child: ListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            children: (data['children'] as List<dynamic>)
                .map((e) => buildWidget(e, context, extension))
                .toList(),
          ),
        );
      case 'timestamp':
        if (data['display'] == 'relative') {
          return Text(
            durationToRelativeTime(
              DateTime.tryParse(data['timestamp'] as String)
                      ?.difference(DateTime.now()) ??
                  Duration.zero,
            ),
            style: const TextStyle(fontSize: 14),
          );
        } else {
          return Text(
            DateTime.tryParse(data['timestamp'] as String)?.toString() ??
                'Unknown',
          );
        }
      case 'entrycard':
        return EntryCard(
          entry:
              Entry.fromJson(data['entry'] as Map<String, dynamic>, extension!),
        );
    }
    return Text(
      "Something ${data['type']}",
      style: const TextStyle(fontSize: 14),
    );
  }

  String getreadTooltip(EntryDetail entry, BuildContext context) {
    switch (entry.type) {
      case MediaType.video:
        return 'Continue Watching';
      case MediaType.comic:
        return 'Continue Reading';
      case MediaType.audio:
        return 'Continue Listening';
      case MediaType.book:
        return 'Continue Reading';
      case MediaType.unknown:
        return 'Continue';
    }
  }

  Widget display(EntryDetail entry) {
    eplist ??= entry.episodes[entry.episodeindex];
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          if (entry is EntrySaved)
            IconButton(
              tooltip: 'BatchDownload',
              onPressed: () {
                int episodes = 10;
                bool deleteread = true;
                showDialog(
                  builder: (context) => AlertDialog(
                    actions: [
                      TextButton(
                        onPressed: () async {
                          for (int i = entry.getlastReadIndex();
                              i < entry.getlastReadIndex() + episodes;
                              i++) {
                            if (await entry.isDownloaded(eplist!, i)) {
                              continue;
                            }
                            await entry.download(eplist!, i);
                          }
                          for (int ep = 0;
                              ep < entry.getlastReadIndex();
                              ep++) {
                            if (await entry.isDownloaded(eplist!, ep)) {
                              continue;
                            }
                            await entry.delete(eplist!, ep);
                          }
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                    content: StatefulBuilder(
                      builder: (context, setState) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Delete Read Episodes'),
                          Checkbox(
                            value: deleteread,
                            onChanged: (value) => setState(() {
                              deleteread = value!;
                            }),
                          ),
                          Text('How Many Episodes to download: $episodes'),
                          Slider(
                            value: episodes.toDouble(),
                            min: 1,
                            max:
                                (entry.totalepisodes - entry.getlastReadIndex())
                                    .toDouble(),
                            divisions:
                                entry.totalepisodes - entry.getlastReadIndex(),
                            onChanged: (value) => setState(
                              () {
                                episodes = value.toInt();
                              },
                            ),
                          ),
                          const ConstructionWarning(),
                        ],
                      ),
                    ),
                  ),
                  context: context,
                );
              },
              icon: const Icon(Icons.download_for_offline),
            ),
          IconButton(
            tooltip: 'Refresh Entry',
            onPressed: () {
              refreshing = true;
              setState(() {});
              entry.refresh().then((value) {
                refreshing = false;
                _entry = Future.value(value ?? entry);
                setState(() {});
              });
              // setState(() {
              //   _entry = entry.refresh();
              // });
            },
            icon: (entry.refreshing || refreshing)
                ? SizedBox(
                    width: (IconTheme.of(context).size ?? 20) * 0.6,
                    height: (IconTheme.of(context).size ?? 20) * 0.6,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: getIconColor(context),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Open in Browser',
            onPressed: () {
              launchUrl(Uri.parse(entry.weburl));
            },
            icon: const Icon(Icons.web_outlined),
          ),
          IconButton(
            tooltip: 'In Construction',
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
          ),
          // PopupMenuButton()
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => navSource(
          context,
          entry.source(eplist!, entry.getlastReadIndex()),
        )
        // entry
        // .source(eplist!.getEpisode(entry.getlastReadIndex()))
        // .then((value) => context.push("/any", extra: value!.navReader()))
        ,
        tooltip: getreadTooltip(entry, context),
        child: const Icon(Icons.play_arrow),
      ),
      body: isVertical(context)
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  shrinkWrap: true,
                  controller: scrollController,
                  children: [
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: true),
                      child: SizedBox(
                        // height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: buildDescription(entry, context),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: buildEpisodes(entry, context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width / 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListView(
                        children: [buildDescription(entry, context)],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: buildEpisodes(entry, context),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: selected.isEmpty
          ? null
          : SizedBox(
              height: 70,
              width: MediaQuery.of(context).size.width,
              child: Row(
                children: [
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        setState(() {
                          final List<int> completed = [];
                          for (final i in selected) {
                            final data = entry.getEpdata(i);
                            data.completed = !data.completed;
                            if (data.completed) {
                              completed.add(i);
                            }
                          }
                          makeconsumeActivity(
                            entry as EntrySaved,
                            completed,
                            ReadType.marked,
                          );
                          entry.save();
                          selected.clear();
                        });
                      },
                    ),
                  ),
                  if (selected.length == 1 && eplist != null)
                    Expanded(
                      child: IconButton(
                        icon: const Icon(Icons.web_outlined),
                        onPressed: () {
                          launchUrl(
                            Uri.parse(eplist!.episodes[selected.first].weburl),
                          );
                        },
                      ),
                    ),
                  if (selected.length == 1)
                    Expanded(
                      child: IconButton(
                        icon: const Stack(
                          children: [
                            Icon(Icons.done_outlined),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child:
                                  Icon(Icons.arrow_downward_outlined, size: 11),
                            ),
                          ],
                        ),
                        onPressed: () {
                          setState(() {
                            for (var i = 0; i <= selected.first; i++) {
                              entry.complete(i, date: false);
                            }
                            makeconsumeActivity(
                              entry as EntrySaved,
                              List.generate(selected.first, (index) => index),
                              ReadType.marked,
                            );
                            entry.save();
                            selected.clear();
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _entry ??= (GoRouterState.of(context).extra! as Entry).detailed();
    return FutureLoader(
      _entry!,
      error: (context, error) => BareScaffold(
        Text(
          'Error loading Detailedview: $error',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      loading: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      success: (context, data) {
        if (data! is EntrySaved) {
          return StreamBuilder(
            stream: isar.entrySaveds
                .watchObject((data as EntrySaved).id)
                .asBroadcastStream(),
            initialData: data,
            builder: (context, snapshot) {
              final EntrySaved? ent = isar.entrySaveds.getSync(data.id);
              if (ent == null) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Loading...'),
                  ),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
              _entry = Future.value(ent);
              return display(ent);
            },
          );
        }

        final EntryDetail entry = data;

        return display(entry);
      },
    );
  }
}
