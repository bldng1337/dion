
const _recentWindow = 10;

const _minInterval = Duration(hours: 1);

/// Gaps below this are same-day batch drops; when day-scale gaps exist, only
/// those describe the release schedule (daily and slower series all clear
/// it, while multi-drop days do not).
const _batchDropCutoff = Duration(hours: 12);

const _maxInterval = Duration(days: 400);

const _weeklySnapTolerance = Duration(hours: 36);

const _week = Duration(days: 7);

class ReleasePrediction {
  final DateTime nextRelease;

  final Duration interval;

  final double confidence;

  final int sampleSize;

  const ReleasePrediction({
    required this.nextRelease,
    required this.interval,
    required this.confidence,
    required this.sampleSize,
  });

  @override
  String toString() =>
      'ReleasePrediction{nextRelease: $nextRelease, interval: $interval, '
      'confidence: $confidence, sampleSize: $sampleSize}';
}

DateTime? parseEpisodeTimestamp(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.codeUnits.every((c) => c >= 0x30 && c <= 0x39)) {
    return _epochFromDigits(int.tryParse(s));
  }
  // DateTime.parse accepts the T separator, a space separator and optional
  // seconds; it rejects bare HH:MM, so complete that shape first.
  final timeOnly = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})$',
  ).firstMatch(s);
  final normalized = timeOnly == null ? s : '${timeOnly[1]} ${timeOnly[2]}:00';
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null && !_rolledOver(normalized, parsed)) return parsed;
  return _tryParseRfc2822(s);
}

bool _rolledOver(String s, DateTime parsed) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m == null) return false;
  return parsed.year != int.parse(m[1]!) ||
      parsed.month != int.parse(m[2]!) ||
      parsed.day != int.parse(m[3]!);
}

DateTime? _epochFromDigits(int? n) {
  if (n == null || n <= 0) return null; // Mihon uses 0 for "unknown".
  if (n >= 100000000000) return DateTime.fromMillisecondsSinceEpoch(n);
  if (n >= 1000000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
  return null;
}

final _rfc2822Pattern = RegExp(
  r'^\w{3},\s*(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,5})?$',
);

const _rfc2822Months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

const _rfc2822Zones = {
  'GMT': 0,
  'UT': 0,
  'UTC': 0,
  'EST': -5,
  'EDT': -4,
  'CST': -6,
  'CDT': -5,
  'MST': -7,
  'MDT': -6,
  'PST': -8,
  'PDT': -7,
};

DateTime? _tryParseRfc2822(String s) {
  final match = _rfc2822Pattern.firstMatch(s);
  if (match == null) return null;
  final month = _rfc2822Months[(match[2] ?? '').toLowerCase()];
  if (month == null) return null;
  final day = int.parse(match[1]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = match[6] == null ? 0 : int.parse(match[6]!);
  if (day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    return null;
  }
  final naive = DateTime.utc(
    int.parse(match[3]!),
    month,
    day,
    hour,
    minute,
    second,
  );
  if (naive.day != day || naive.month != month) return null;
  final zone = match[7];
  var offsetMinutes = 0;
  if (zone != null && zone.startsWith(RegExp('[+-]'))) {
    final sign = zone.startsWith('-') ? -1 : 1;
    offsetMinutes =
        sign * (int.parse(zone.substring(1, 3)) * 60 + int.parse(
          zone.substring(3, 5),
        ));
  } else if (zone != null) {
    offsetMinutes = (_rfc2822Zones[zone.toUpperCase()] ?? 0) * 60;
  }
  return naive.subtract(Duration(minutes: offsetMinutes));
}

ReleasePrediction? predictNextRelease(
  Iterable<String?> timestamps, {
  DateTime? now,
}) {
  final parsed = <DateTime>[];
  for (final raw in timestamps) {
    if (raw == null) continue;
    final time = parseEpisodeTimestamp(raw);
    if (time != null) parsed.add(time);
  }
  parsed.sort((a, b) => a.compareTo(b));
  final times = <DateTime>[];
  for (final time in parsed) {
    if (times.isEmpty ||
        time.millisecondsSinceEpoch !=
            times.last.millisecondsSinceEpoch) {
      times.add(time);
    }
  }
  if (times.length < 2) return null;
  final tail =
      times.length <= _recentWindow
          ? times
          : times.sublist(times.length - _recentWindow);
  final diffs = <Duration>[];
  for (var i = 1; i < tail.length; i++) {
    final diff = tail[i].difference(tail[i - 1]);
    if (diff > Duration.zero) diffs.add(diff);
  }
  final last = times.last;

  now ??= DateTime.now();
  if (last.isAfter(now)) {
    // The source already dated the next episode.
    return ReleasePrediction(
      nextRelease: last,
      interval: Duration.zero,
      confidence: 0.95,
      sampleSize: diffs.length,
    );
  }

  // Prefer day-scale gaps: same-day batch drops otherwise drag the median
  // down even though they are not the release cadence. Series that release
  // multiple times a day have no day-scale gaps and keep the raw median.
  final dayScale = diffs
      .where((d) => d >= _batchDropCutoff)
      .toList();
  var interval = _median(dayScale.isEmpty ? diffs : dayScale);
  if (interval == null) return null;
  final weeks = (interval.inMilliseconds / _week.inMilliseconds).round();
  if (weeks >= 1 &&
      (interval - _week * weeks).abs() <= _weeklySnapTolerance) {
    interval = _week * weeks;
  }
  if (interval < _minInterval || interval > _maxInterval) return null;

  final mad = _median([
    for (final d in diffs) (d - interval).abs(),
  ]);
  final dispersion =
      mad == null
          ? 0.0
          : 1.0 - (2.5 * mad.inMilliseconds / interval.inMilliseconds).clamp(
            0.0,
            1.0,
          );
  // Few samples mean the regularity is luck until proven otherwise.
  final sizeFactor = (0.6 + 0.08 * diffs.length).clamp(0.0, 1.0);
  return ReleasePrediction(
    nextRelease: last.add(interval),
    interval: interval,
    confidence: dispersion * sizeFactor,
    sampleSize: diffs.length,
  );
}

Duration? _median(List<Duration> values) {
  if (values.isEmpty) return null;
  values.sort();
  return values[values.length ~/ 2];
}
