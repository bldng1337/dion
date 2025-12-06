import 'package:dionysos/data/activity/episode.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

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
