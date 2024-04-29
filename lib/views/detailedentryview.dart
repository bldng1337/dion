import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/sync.dart';
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                icon: const Icon(Icons.download_done))
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
                      icon: const Icon(Icons.download));
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
  var episodescrollController = ScrollController();
  var scrollController = ScrollController();
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
    List<int> ceplist = eplist!.episodes.indexed
        // .where((element) => entry.getEpdata(element.$1).isBookmarked)
        .map((e) => e.$1)
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${ceplist.length} Chapters"),
          PopupMenuButton<AEpisodeList?>(
            itemBuilder: (BuildContext context) => [
              ...entry.episodes.map((e) => PopupMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        Text(e.title),
                        const Spacer(),
                        Text("${e.episodes.length}")
                      ],
                    ),
                  )),
              const PopupMenuDivider(),
            ],
            onSelected: (value) {
              if (value == null) {
                return;
              }
              setState(
                () {
                  selected.clear();
                  eplist = value;
                },
              );
            },
            // icon: const Icon(Icons.source),
            tooltip: "Choose Source",
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.source),
                Text("Sources - ${eplist?.title ?? "Unknown"}")
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
                int index = ceplist[cindex];
                var ep = eplist!.getEpisode(index);
                return ListTile(
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.all(5),
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
                  title: Row(children: [
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
                      ep?.name ?? "Unknown",
                      maxLines: 1,
                    )),
                    if (entry is EntrySaved)
                      DownloadButton(entry, eplist!, index)
                  ]),
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
                  subtitle: Text("Chapter ${index + 1}"),
                );
              },
            ))
        ],
      ),
    );
  }

  Widget buttonbar(EntryDetail entry, BuildContext context) {
    bool isinLibrary = entry is EntrySaved;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(isinLibrary ? Icons.book : Icons.book_outlined),
          tooltip: isinLibrary ? "Remove from Library" : "Add to Library",
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
              EntrySaved newentry = EntrySaved.fromEntry(entry);
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
          tooltip: "Share",
          onPressed: () => share("${entry.title}: ${entry.url}"),
        ),
        if (isinLibrary)
          IconButton(
            tooltip: "In Construction",
            icon: const Icon(Icons.hourglass_empty),
            onPressed: () => print("Pressed"),
          ),
      ],
    );
  }

  Widget buildDescription(EntryDetail entry, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (entry.ext == null)
          Container(
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
                  "Warning Extension for this Entry seems not loaded or cant be found",
                  style: TextStyle(color: Theme.of(context).indicatorColor),
                ))
              ],
            ),
          ),
        SizedBox(
          height: 200,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  child: FancyShimmerImage(
                    boxDecoration: const BoxDecoration(boxShadow: [
                      BoxShadow(offset: Offset(0.5, 0.9), blurRadius: 3.0)
                    ]),
                    width: 130,
                    height: 200,
                    boxFit: BoxFit.contain,
                    imageUrl: entry.cover ?? "",
                    cacheKey: entry.url,
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
                        imageUrl: entry.cover ?? "",
                        errorWidget: const Icon(Icons.image, size: 130),
                        imageBuilder: (context, imageProvider) =>
                            GestureDetector(
                          onLongPress: () =>
                              launchUrl(Uri.parse(entry.cover ?? "")),
                          onDoubleTap: () =>
                              launchUrl(Uri.parse(entry.cover ?? "")),
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
                            if (entry.author != null &&
                                entry.author!.isNotEmpty)
                              Text(
                                entry.author!.join(" • "),
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                ),
                              ),
                            Text(
                              "${entry.ext?.data?.name ?? "Unkown"} • ${entry.status.name}",
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                fontSize: 16.0,
                              ),
                            ),
                            if (entry.views != null)
                              Text(
                                "${formatNumber(entry.views!)} Views",
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                ),
                              ),
                          ],
                        )))
              ]),
        ),
        buttonbar(entry, context),
        SizedBox(
          height: 40,
          child: ListView(
            physics: isVertical(context) ? const ClampingScrollPhysics() : null,
            scrollDirection: Axis.horizontal,
            children: entry.genres
                .map((e) => Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15))),
                        child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Text(e,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .background))),
                      ),
                    ))
                .toList(),
          ),
        ),
        Text(
          maxLines: 8,
          entry.description ?? "",
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontSize: 16.0,
          ),
        ),
      ],
    );
  }

  String getreadTooltip(EntryDetail entry, BuildContext context) {
    switch (entry.type) {
      case MediaType.video:
        return "Continue Watching";
      case MediaType.comic:
        return "Continue Reading";
      case MediaType.audio:
        return "Continue Listening";
      case MediaType.book:
        return "Continue Reading";
      case MediaType.unknown:
        return "Continue";
    }
  }

  Widget display(EntryDetail entry) {
    eplist ??= entry.episodes[0];
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          if (entry is EntrySaved)
            IconButton(
                tooltip: "BatchDownload",
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
                            child: const Text("Submit"))
                      ],
                      content: StatefulBuilder(
                        builder: (context, setState) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            const Text("Delete Read Episodes"),
                            Checkbox(
                              value: deleteread,
                              onChanged: (value) => setState(() {
                                deleteread = value!;
                              }),
                            ),
                            Text("How Many Episodes to download: $episodes"),
                            Slider(
                                value: episodes.toDouble(),
                                min: 1,
                                max: (entry.totalepisodes -
                                        entry.getlastReadIndex())
                                    .toDouble(),
                                divisions: (entry.totalepisodes -
                                    entry.getlastReadIndex()),
                                onChanged: (value) => setState(
                                      () {
                                        episodes = value.toInt();
                                      },
                                    )),
                                    const ConstructionWarning(),
                          ],
                        ),
                      ),
                    ),
                    context: context,
                  );
                },
                icon: const Icon(Icons.download_for_offline)),
          IconButton(
              tooltip: "Refresh Entry",
              onPressed: () {
                setState(() {});
                _entry = entry.refresh();
              },
              icon: entry.refreshing
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.refresh)),
          IconButton(
              tooltip: "Open in Browser",
              onPressed: () {
                launchUrl(Uri.parse(entry.url));
              },
              icon: const Icon(Icons.web_outlined)),
          IconButton(
              tooltip: "In Construction",
              onPressed: () {},
              icon: const Icon(Icons.filter_list)),
          // PopupMenuButton()
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => navSource(
              context, entry.source(eplist!, entry.getlastReadIndex()))
          // entry
          // .source(eplist!.getEpisode(entry.getlastReadIndex()))
          // .then((value) => context.push("/any", extra: value!.navReader()))
          ,
          tooltip: getreadTooltip(entry, context),
          child: const Icon(Icons.play_arrow)),
      body: isVertical(context)
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
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
                                  child: buildDescription(entry, context)),
                            )),
                        SizedBox(
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                          child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: buildEpisodes(entry, context)),
                        ),
                      ])))
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
                        ))),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: buildEpisodes(entry, context)),
                ),
              ],
            ),
      bottomNavigationBar: selected.isEmpty
          ? null
          : SizedBox(
              height: 70,
              width: MediaQuery.of(context).size.width,
              child: Row(children: [
                Expanded(
                    child: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    setState(() {
                      List<int> completed = [];
                      for (var i in selected) {
                        final data = entry.getEpdata(i);
                        data.completed = !data.completed;
                        if (data.completed) {
                          completed.add(i);
                        }
                      }
                      makeconsumeActivity(
                          entry as EntrySaved, completed, ReadType.marked);
                      entry.save();
                      selected.clear();
                    });
                  },
                )),
                if (selected.length == 1 && eplist != null)
                  Expanded(
                      child: IconButton(
                    icon: const Icon(Icons.web_outlined),
                    onPressed: () {
                      launchUrl(
                          Uri.parse(eplist!.episodes[selected.first].url));
                    },
                  )),
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
                                Icon(Icons.arrow_downward_outlined, size: 11))
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
                            ReadType.marked);
                        entry.save();
                        selected.clear();
                      });
                    },
                  )),
              ]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _entry ??= (GoRouterState.of(context).extra! as Entry).detailed();
    return FutureLoader(
      _entry!,
      error: (context, error) => BareScaffold(Text(
        'Error loading Detailedview: $error',
        style: Theme.of(context).textTheme.headlineMedium,
      )),
      loading: (context) => Scaffold(
        appBar: AppBar(
          title: const Text("Loading..."),
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
              EntrySaved? ent = isar.entrySaveds.getSync(data.id);
              if (ent == null) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text("Loading..."),
                  ),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
              _entry = Future.value(ent);
              return display(ent);
            },
          );
        }
        EntryDetail entry = data;
        return display(entry);
      },
    );
  }
}
