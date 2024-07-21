import 'dart:convert';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:huge_listview/huge_listview.dart';
import 'package:humanize_duration/humanize_duration.dart';
import 'package:isar/isar.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Future<Widget> page() async {
    const int pagesize = 10;
    final max = await isar.activitys.count();
    return HugeListView(
      listViewController: HugeListViewController(totalItemCount: max),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Nav(
      child: FutureLoader(
        page(),
        success: (BuildContext context, Widget data) => data,
      ),
    );
  }
}

EntryDetail? resolveEntry(dynamic entrydata) {
  //TODO: expand
  return isar.entrySaveds.getSync(entrydata['id'] as int);
}

class ActivityCard extends StatelessWidget {
  final Activity act;
  const ActivityCard({super.key, required this.act});

  @override
  Widget build(BuildContext context) {
    switch (act.type) {
      case 'consume':
        final dynamic data = json.decode(act.data);
        final EntryDetail? entry = resolveEntry(data['entry']);
        final String title = data['title'] as String;

        final List<String> body = [
          humanizeDuration(
            act.getDuration(),
            options: const HumanizeOptions(
              units: [Units.hour, Units.minute, Units.second],
            ),
          ),
          if ((data['episodesread'] as List).isNotEmpty)
            "${entry?.type.getAction()} ${(data["episodesread"] as List).length} ${entry?.type.getEpName()}",
          if ((data['episodesmarked'] as List).isNotEmpty)
            "Marked ${(data["episodesmarked"] as List).length} ${entry?.type.getEpName()}",
        ];

        return ListTile(
          onTap: () {
            if (entry != null) {
              context.push('/entryview', extra: entry);
            }
          },
          leading: FancyShimmerImage(
            width: 30,
            height: 60,
            imageUrl: entry?.cover ?? 'https://0.0.0.0/',
            errorWidget: const Icon(Icons.image, size: 30),
          ),
          title: Text(title),
          subtitle: Text(body.join(' • ')),
        );
    }
    return Container();
  }
}
