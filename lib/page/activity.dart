import 'dart:convert';

import 'package:dionysos/Entry.dart';
import 'package:dionysos/activity.dart';
import 'package:dionysos/main.dart';
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:huge_listview/huge_listview.dart';
import 'package:humanize_duration/humanize_duration.dart';
import 'package:isar/isar.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  Widget build(BuildContext context) {
    int pagesize = 10;
    return Nav(
      child: HugeListView(
        pageSize: pagesize,
        startIndex: 0,
        pageFuture: (index) {
          return isar.activitys
              .where(sort: Sort.asc)
              .sortByBeginDesc()
              .offset(index * pagesize)
              .limit(pagesize)
              .findAll();
        },
        thumbBuilder: DraggableScrollbarThumbs.SemicircleThumb,
        itemBuilder: (context, index, entry) => ActivityCard(act: entry),
        placeholderBuilder: (context, index) => SizedBox(
          height: MediaQuery.of(context).size.height,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

EntryDetail? resolveEntry(dynamic entrydata) {
  //TODO: expand
  return isar.entrySaveds.getSync(entrydata["id"] as int);
}

String getAction(MediaType m) {
  return switch (m) {
    MediaType.video => "Watched",
    MediaType.comic => "Read",
    MediaType.audio => "Listened to",
    MediaType.book => "Read",
  };
}

String getEpName(MediaType m) {
  return switch (m) {
    MediaType.video => "Episodes",
    MediaType.comic => "Chapter",
    MediaType.audio => "Episodes",
    MediaType.book => "Chapter",
  };
}

class ActivityCard extends StatelessWidget {
  final Activity act;
  const ActivityCard({super.key, required this.act});

  @override
  Widget build(BuildContext context) {
    switch (act.type) {
      case "consume":
        dynamic data = json.decode(act.data);
        EntryDetail? entry = resolveEntry(data["entry"]);
        int start = 0;
        int end = 0;

        String title = data["title"];

        List<String> body = [
          humanizeDuration(act.getDuration(),
              options: const HumanizeOptions(
                  units: [Units.hour, Units.minute, Units.second])),
          if ((data["episodesread"] as List).isNotEmpty)
            "${getAction(entry?.type ?? MediaType.video)} ${(data["episodesread"] as List).length} ${getEpName(entry?.type ?? MediaType.video)}",
          if ((data["episodesmarked"] as List).isNotEmpty)
            "Marked ${(data["episodesmarked"] as List).length} ${getEpName(entry?.type ?? MediaType.video)}",
        ];

        return ListTile(
          onTap: () {
            if (entry != null) {
              context.push("/entryview", extra: entry);
            }
          },
          leading: FancyShimmerImage(
              width: 30,
              height: 60,
              imageUrl: entry?.cover ?? "",
              errorWidget: const Icon(Icons.image, size: 30)),
          title: Text(title),
          subtitle: Text(body.join(" • ")),
        );
    }
    return Container();
  }
}
