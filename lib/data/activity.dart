import 'dart:math';

import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';
import 'package:uuid/uuid.dart';

class Activity with DBConstClass {
  final DateTime time;
  final String id;

  const Activity(this.time, this.id);

  factory Activity.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'episode':
        return EpisodeActivity.fromJson(json);
      default:
        return Activity(
          DateTime.parse(json['time'] as String),
          json['aid'] as String,
        );
    }
  }

  @override
  Map<String, dynamic> toDBJson() {
    return {'type': 'activity', 'aid': id, 'time': time};
  }

  @override
  DBRecord get dbId => DBRecord('activity', id);
}

class EpisodeActivity extends Activity {
  final int fromepisode;
  final int toepisode;
  final Entry? entry;
  final String extensionid;
  final Duration duration;

  const EpisodeActivity({
    required this.fromepisode,
    required this.toepisode,
    required this.entry,
    required this.extensionid,
    this.duration = Duration.zero,
    required DateTime time,
    required String id,
  }) : super(time, id);

  factory EpisodeActivity.fromJson(Map<String, dynamic> json) {
    if (json['entry'] != null &&
        locate<SourceExtension>().tryGetExtension(
              json['extensionid'] as String,
            ) !=
            null) {
      return EpisodeActivity(
        fromepisode: json['fromepisode'] as int,
        toepisode: json['toepisode'] as int,
        entry: Entry.fromJson(json['entry'] as Map<String, dynamic>),
        extensionid: json['extensionid'] as String,
        duration: Duration(seconds: json['duration'] as int),
        time: json['time'] as DateTime,
        id: json['aid'] as String,
      );
    }
    return EpisodeActivity(
      fromepisode: json['fromepisode'] as int,
      toepisode: json['toepisode'] as int,
      entry: null,
      extensionid: json['extensionid'] as String,
      duration: Duration(seconds: json['duration'] as int),
      time: json['time'] as DateTime,
      id: json['aid'] as String,
    );
  }

  Activity copyWith({
    int? fromepisode,
    int? toepisode,
    Entry? entry,
    String? extensionid,
    DateTime? time,
    Duration? duration,
  }) {
    return EpisodeActivity(
      fromepisode: fromepisode ?? this.fromepisode,
      toepisode: toepisode ?? this.toepisode,
      entry: entry ?? this.entry,
      extensionid: extensionid ?? this.extensionid,
      time: time ?? this.time,
      duration: duration ?? this.duration,
      id: id,
    );
  }

  @override
  Map<String, dynamic> toDBJson() {
    return {
      ...super.toDBJson(),
      'type': 'episode',
      'fromepisode': fromepisode,
      'toepisode': toepisode,
      'entry': entry?.toEntryJson(),
      'extensionid': extensionid,
      'duration': duration.inSeconds,
    };
  }
}

Future<void> finishEpisode(EpisodePath ep) async {
  try {
    final db = locate<Database>();
    final activity = await db.getLastActivity();
    if (activity != null &&
        activity is EpisodeActivity &&
        activity.extensionid == ep.extension.id &&
        activity.time
            .add(activity.duration)
            .isAfter(DateTime.now().subtract(const Duration(minutes: 30)))) {
      await db.addActivity(
        activity.copyWith(
          toepisode: max(ep.episodenumber, activity.toepisode),
          fromepisode: min(ep.episodenumber, activity.fromepisode),
          duration: DateTime.now().difference(activity.time),
        ),
      );
      return;
    }
    await db.addActivity(
      EpisodeActivity(
        id: const Uuid().v4(),
        fromepisode: ep.episodenumber,
        toepisode: ep.episodenumber,
        entry: ep.entry,
        extensionid: ep.extension.id,
        time: DateTime.now(),
      ),
    );
  } catch (e, stack) {
    logger.e(e, stackTrace: stack);
  }
}
