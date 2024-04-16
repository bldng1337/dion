import 'dart:convert';
import 'dart:math';

import 'package:dionysos/Entry.dart';
import 'package:dionysos/main.dart';
import 'package:isar/isar.dart';

part 'activity.g.dart';

enum ReadType { read, started, marked }

Duration act = const Duration(minutes: 30);
void makeconsumeActivity(EntrySaved entry, List<int> chapter, ReadType type) async {
  Activity? last = await isar.activitys
      .filter()
      .typeEqualTo("consume")
      .sortByEndDesc()
      .findFirst();
  DateTime now = DateTime.now();
  if (last != null) {
    dynamic data = json.decode(last.data);
    if (data["entry"]["id"] == entry.id &&
        last.end.difference(now).abs().compareTo(act) <= 0) {
      last.end = now;
      if (type == ReadType.read&&!(data["episodesread"] as List).contains(chapter)){
        (data["episodesread"] as List).addAll(chapter);
      }
      if (type == ReadType.marked&&!(data["episodesmarked"] as List).contains(chapter)){
        (data["episodesmarked"] as List).addAll(chapter);
      }
      data["lastchapter"]=chapter.last;
      last.data = json.encode(data);
      await isar.writeTxn(() async {
        isar.activitys.put(last);
      });
      return;
    }
  }
  Activity newact = Activity.init();
  newact.type = "consume";
  newact.begin = now;
  newact.end = now;
  newact.data = json.encode({
    "title": entry.title,
    "episodesread": [if (type == ReadType.read) ...chapter],
    "episodesmarked": [if (type == ReadType.marked) ...chapter],
    "lastchapter": chapter,
    "entry": {"id": entry.id, "url": entry.url, "extension": entry.extname}
  });
  await isar.writeTxn(() async {
    isar.activitys.put(newact);
  });
}

@collection
class Activity {
  Id id = Isar.autoIncrement;
  String deviceid="";
  String type = "";
  String data = "{}";
  @Index()
  DateTime begin = DateTime(0);
  @Index()
  DateTime end = DateTime(0);

  Duration getDuration() {
    return begin.difference(end);
  }

  Activity();
  Activity.init(){
    deviceid=deviceId;
  }
}
