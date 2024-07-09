import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/extension/extensionmanager.dart';
import 'package:dionysos/extension/jsextension.dart';
import 'package:dionysos/main.dart';
import 'package:endless/stream/endless_stream_controller.dart';
import 'package:endless/stream/endless_stream_grid_view.dart';
import 'package:dionysos/widgets/image.dart';
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
  int count = 0;
  MediaType? filtertype;

  Future<void> loadmore() async {
    if (search.isNotEmpty) {
      await streamController.addStream(ExtensionManager().search(
        count++,
        search,
        extfilter: (e) {
          if (filtertype == null) {
            return true;
          }
          return  e.data?.type?.contains(filtertype)??false;
        },
      ),);
    } else {
      await streamController
          .addStream(ExtensionManager().browse(count++, sort, extfilter: (e) {
        if (filtertype == null) {
          return true;
        }
        return filtertype == e.data?.type;
      },),);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Nav(
        child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          //Search
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
                child: SearchBar(
              trailing: [
                DropdownButton<MediaType>(
                  // icon: const Icon(Icons.filter_alt_sharp),
                  items: [
                    const DropdownMenuItem(
                      child: Icon(Icons.disabled_by_default),
                    ),
                    ...MediaType.values.map((e) => DropdownMenuItem(
                          value: e,
                          child: Icon(e.icon()),
                        ),),
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
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.val),
                              ),)
                          .toList(),
                      onChanged: (e) {
                        if (e != null && search.isEmpty) {
                          setState(() {
                            controller.clear(lazy: true);
                            sort = e;
                            count = 0;
                            loadmore();
                          });
                        }
                      },),
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
            ),),
          ],
        ),
      ),
      Expanded(
          //Items
          child: EndlessStreamGridView<Entry>(
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
      ),),
    ],),);
  }
}

class EntryCard extends StatelessWidget {
  final Entry entry;
  final bool selection;
  final bool selected;
  final Function? onselect;
  const EntryCard(
      {super.key,
      required this.entry,
      this.selected = false,
      this.onselect,
      this.selection = false,});

  @override
  Widget build(BuildContext context) {
    const double width = 300 / 1.5;
    const double height = 600 / 2;
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
              imageUrl: entry.cover ?? '',
              httpHeaders: (json.decode(entry.coverheader ?? '{}') as Map<String, dynamic>).cast(),
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
                    Theme.of(context).shadowColor.withOpacity(0.3),
                    Theme.of(context).shadowColor.withOpacity(1),
                  ],
                  stops: const [0, 0.75, 1],
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
                          Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(10)),
                                color: Theme.of(context).primaryColor,
                              ),
                              margin: const EdgeInsets.all(5),
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '${(entry as EntrySaved).episodescompleted}/${(entry as EntrySaved).episodes.reduce((value, element) => value.episodes.length > element.episodes.length ? value : element).episodes.length}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),),
                        Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10)),
                              color: Theme.of(context).primaryColor,
                            ),
                            margin: const EdgeInsets.all(5),
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              entry.type.icon(),
                              size: (Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.fontSize ??
                                      0) *
                                  1.45,
                              color:
                                  Theme.of(context).textTheme.labelLarge?.color,
                            ),),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const Spacer(),
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
                      maxLines: 4,
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
