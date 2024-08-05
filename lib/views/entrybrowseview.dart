import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:country_flags/country_flags.dart';
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/util/settingsapi.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:endless/stream/endless_stream_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EntryBrowseView extends StatefulWidget {
  const EntryBrowseView({super.key});

  @override
  State<EntryBrowseView> createState() => _EntryBrowseViewState();
}

class _EntryBrowseViewState extends State<EntryBrowseView> {
  final streamController = StreamController<List<Entry>>();
  final controller = EndlessStreamController<Entry>();
  String search = '';
  SortMode sort = SortMode.latest;
  Extension? filterextension;
  int count = 0;
  MediaType? filtertype;

  Future<void> loadmore() async {
    if (search.isNotEmpty) {
      await streamController.addStream(
        ExtensionManager().search(
          count++,
          search,
          extfilter: filterExtension,
        ),
      );
    } else {
      await streamController.addStream(
        ExtensionManager().browse(
          count++,
          sort,
          extfilter: filterExtension,
        ),
      );
    }
  }

  bool filterExtension(Extension e) {
    if (filterextension != null) {
      return e == filterextension;
    }
    if (filtertype == null) {
      return true;
    }
    return e.data?.type?.contains(filtertype) ?? false;
  }

  Widget showFilterView(BuildContext context) {
    return StatefulBuilder(
      builder: (context, popsetState) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<MediaType>(
                  // icon: const Icon(Icons.filter_alt_sharp),
                  items: [
                    const DropdownMenuItem(
                      child: Icon(Icons.disabled_by_default),
                    ),
                    ...MediaType.values.map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Icon(e.icon()),
                      ),
                    ),
                  ],
                  value: filtertype,
                  onChanged: (value) {
                    setState(() {
                      controller.clear(lazy: true);
                      filtertype = value;
                      count = 0;
                      loadmore();
                    });
                  },
                ),
                if (search.isEmpty)
                  DropdownButton(
                    padding: const EdgeInsets.only(left: 5),
                    value: sort,
                    items: SortMode.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.val),
                          ),
                        )
                        .toList(),
                    onChanged: (e) {
                      if (e != null && search.isEmpty) {
                        setState(() {
                          controller.clear(lazy: true);
                          sort = e;
                          count = 0;
                          loadmore();
                          popsetState(() {});
                        });
                      }
                    },
                  ),
                DropdownButton<Extension?>(
                  value: filterextension,
                  items: [
                    const DropdownMenuItem(
                      child: Icon(Icons.disabled_by_default),
                    ),
                    ...ExtensionManager().loaded.map(
                          (ext) => DropdownMenuItem(
                            value: ext,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: FancyShimmerImage(
                                    imageUrl:
                                        ext.data?.icon ?? 'https://0.0.0.0/',
                                    cacheKey: ext.data?.icon ?? '',
                                    width: 24,
                                    height: 24,
                                    errorWidget:
                                        const Icon(Icons.image, size: 24),
                                  ),
                                ),
                                Text(
                                  ext.data?.name ?? 'Unknown',
                                  style: !ext.enabled
                                      ? const TextStyle(
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  onChanged: (value) => setState(() {
                    controller.clear(lazy: true);
                    filterextension = value;
                    count = 0;
                    loadmore();
                    popsetState(() {});
                  }),
                ),
              ],
            ),
          ),
          if (filterextension != null)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              width: MediaQuery.of(context).size.width * 0.8,
              child: ExtensionSettingPageBuilder(
                filterextension!,
                SettingType.search,
              ).barebuild(
                () => setState(() {
                  controller.clear(lazy: true);
                  count = 0;
                  loadmore();
                  popsetState(() {});
                }),
                nested: true,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Nav(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              //Search
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: SearchBar(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    trailing: [
                      IconButton(
                        icon: const Icon(Icons.filter_alt_sharp),
                        onPressed: () {
                          if (!context.mounted) {
                            return;
                          }
                          if (isVertical(context)) {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => showFilterView(context),
                            );
                          } else {
                            showAdaptiveDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: showFilterView(context),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                    hintText: 'Search',
                    onSubmitted: (a) {
                      setState(() {
                        controller.clear(lazy: true);
                        search = a;
                        count = 0;
                        loadmore();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            //Items
            child: getEntryList(context),
          ),
        ],
      ),
    );
  }

  Widget getEntryList(BuildContext context) {
    if (ExtensionManager().count(extfilter: filterExtension) == 0) {
      return const Center(
        child: Text('No Extensions installed or loaded that fit the filter'),
      );
    }
    return EndlessStreamGridView<Entry>(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        childAspectRatio: 0.69,
        maxCrossAxisExtent: 220,
      ),
      extentAfterFactor: 0.7,
      controller: controller,
      emptyBuilder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
      // A function called when you scroll past the configurable `extentAfterFactor` to tell the stream to add more items.
      loadMore: loadmore,
      // Items emitted on the stream are added to the scroll view. The scroll view knows to not try and fetch any more items
      // once the stream has completed.
      stream: streamController.stream,
      itemBuilder: (
        context, {
        required item,
        required index,
        required totalItems,
      }) {
        return EntryCard(
          entry: item,
        );
      },
      loadMoreBuilder: (context) => TextButton(
        child: const Text('load more'),
        onPressed: () => controller.loadMore(),
      ),
    );
  }
}

class EntryCard extends StatelessWidget {
  final Entry entry;
  final bool selection;
  final bool selected;
  final Function? onselect;
  const EntryCard({
    super.key,
    required this.entry,
    this.selected = false,
    this.onselect,
    this.selection = false,
  });

  Widget makeBadge(BuildContext context, Widget child) {
    final double badgesize =
        (Theme.of(context).textTheme.labelMedium?.fontSize ?? 0) * 1.3;
    return Container(
      height: badgesize + 9,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        color: Theme.of(context).primaryColor,
      ),
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.all(4),
      child: Center(
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double width = 300 / 1.5;
    const double height = 600 / 2;
    final double badgesize =
        (Theme.of(context).textTheme.labelMedium?.fontSize ?? 0) * 1.35;
    // if(entry.cover==null)
    return GestureDetector(
      onTap: () {
        if (selection && onselect != null) {
          onselect!();
          return;
        }
        context.push('/entryview', extra: entry);
      },
      onLongPress: () => onselect?.call(),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            FancyShimmerImage(
              width: width,
              imageUrl: entry.cover ?? 'https://0.0.0.0/',
              httpHeaders: (json.decode(entry.coverheader ?? '{}')
                      as Map<String, dynamic>)
                  .cast(),
              boxFit: BoxFit.cover,
              errorWidget: Icon(Icons.image, size: min(width, height)),
            ),
            Container(
              height: height,
              width: width,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).shadowColor.withOpacity(0.1),
                    Theme.of(context).shadowColor.withOpacity(0.5),
                    Theme.of(context).shadowColor.withOpacity(1),
                  ],
                  stops: const [0, 0.6, 0.75, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: width,
                    height: height / 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry is EntrySaved)
                          makeBadge(
                            context,
                            Text(
                              '${(entry as EntrySaved).episodescompleted}/${(entry as EntrySaved).totalepisodes}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        if (entry is! EntrySaved && entry.length != null)
                          makeBadge(
                            context,
                            Text(
                              '${entry.length}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        makeBadge(
                          context,
                          Icon(
                            entry.type.icon(),
                            size: badgesize,
                            color:
                                Theme.of(context).textTheme.labelMedium?.color,
                          ),
                        ),
                        if (entry.language != null)
                          makeBadge(
                            context,
                            Center(
                              child: CountryFlag.fromLanguageCode(
                                entry.language!,
                                height: badgesize * 0.85,
                                width: badgesize * 0.85,
                                shape: const RoundedRectangle(2),
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (entry.ext != null)
                          makeBadge(
                            context,
                            Center(
                              child: FancyShimmerImage(
                                imageUrl:
                                    entry.ext?.data?.icon ?? 'https://0.0.0.0/',
                                cacheKey: entry.ext?.data?.icon ?? '',
                                width: badgesize * 0.9,
                                height: badgesize * 0.9,
                                errorWidget:
                                    Icon(Icons.image, size: badgesize * 0.9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, bottom: 1),
                    child: Row(
                      children: [
                        if (entry.rating != null)
                          Stardisplay(
                            color: Colors.yellow[300]!,
                            width: badgesize * 0.85,
                            height: badgesize * 0.85,
                            fill: entry.rating!,
                          ),
                        const Spacer(),
                        if ((entry.views ?? 0) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatNumber(entry.views!),
                                style: const TextStyle(
                                  fontSize: 13.0,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.remove_red_eye,
                                  size: 15,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 13.0,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(offset: Offset(0.5, 0.9), blurRadius: 3.0),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: width,
              height: height,
              color: selected
                  ? Theme.of(context).primaryColor.withAlpha(100)
                  : Colors.transparent,
            ),
            if (entry is EntrySaved && (entry as EntrySaved).refreshing)
              ColoredBox(
                color: Theme.of(context).disabledColor.withAlpha(200),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
