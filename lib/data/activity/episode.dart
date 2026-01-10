
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/entry/entry.dart';

class EpisodeActivity extends Activity {
  final int fromepisode;
  final int toepisode;
  final Entry entry;
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

  EpisodeActivity copyWith({
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
      'entry': entry.toEntryJson(),
      'extensionid': extensionid,
      'duration': duration.inSeconds,
    };
  }
}

// Future<void> finishEpisode(EpisodePath ep) async {
//   try {
//     final db = locate<Database>();
//     final activity = await db.getLastActivity();
//     if (activity != null &&
//         activity is EpisodeActivity &&
//         activity.extensionid == ep.extensionid &&
//         activity.entry.id == ep.entry.id &&
//         activity.time
//             .add(activity.duration)
//             .add(const Duration(minutes: 30))
//             .isAfter(DateTime.now()) &&
//         (activity.fromepisode - 1 <= ep.episodenumber ||
//             activity.toepisode + 1 >= ep.episodenumber)) {
      // await db.addActivity(
      //   activity.copyWith(
      //     toepisode: max(ep.episodenumber, activity.toepisode),
      //     fromepisode: min(ep.episodenumber, activity.fromepisode),
      //     duration: DateTime.now().difference(activity.time),
      //   ),
      // );
//       return;
//     }
//     await db.addActivity(
//       EpisodeActivity(
//         id: const Uuid().v4(),
//         fromepisode: ep.episodenumber,
//         toepisode: ep.episodenumber,
//         entry: ep.entry,
//         extensionid: ep.extensionid,
//         time: DateTime.now(),
//       ),
//     );
//   } catch (e, stack) {
//     logger.e(e, stackTrace: stack);
//   }
// }
