import 'package:dionysos/data/activity/episode.dart';
import 'package:metis/adapter/dataclass.dart';
import 'package:metis/metis.dart';

/// Identifies the device an [Activity] was created on. Recorded with every
/// locally created activity and synced along with it, so a shared history
/// can tell which device a session happened on.
class DeviceRef {
  final String deviceId;
  final String name;

  const DeviceRef({required this.deviceId, required this.name});

  factory DeviceRef.fromJson(Map<String, dynamic> json) => DeviceRef(
    deviceId: json['id'] as String,
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'id': deviceId, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is DeviceRef && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

class Activity with DBConstClass {
  final DateTime time;
  final String id;
  final DeviceRef? device;

  const Activity(this.time, this.id, {this.device});

  static DateTime parseTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw ArgumentError.value(value, 'time', 'not a datetime or ISO string');
  }

  static DeviceRef? parseDevice(Object? value) {
    // Activities created before device tracking (or restored from old
    // backups) have no device information.
    if (value is! Map) return null;
    return DeviceRef.fromJson(Map<String, dynamic>.from(value));
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'episode':
        return EpisodeActivity.fromJson(json);
      default:
        return Activity(
          parseTime(json['time']),
          json['aid'] as String,
          device: parseDevice(json['device']),
        );
    }
  }

  @override
  Map<String, dynamic> toDBJson() {
    return {
      'type': 'activity',
      'aid': id,
      'time': time,
      if (device != null) 'device': device!.toJson(),
    };
  }

  @override
  DBRecord get dbId => DBRecord('activity', id);

  Activity copyWith({DateTime? time, DeviceRef? device}) =>
      Activity(time ?? this.time, id, device: device ?? this.device);
}
