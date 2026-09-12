import 'package:dionysos/utils/release_prediction.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = Duration(days: 1);
const _week = Duration(days: 7);

String _iso(DateTime time) => time.toUtc().toIso8601String();

String _millis(DateTime time) => time.millisecondsSinceEpoch.toString();

DateTime _utc(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

void main() {
  group('parseEpisodeTimestamp', () {
    test('parses common formats', () {
      final expected = _utc(2024, 1, 5, 12, 30);
      final expectedMillis = expected.millisecondsSinceEpoch;
      expect(
        parseEpisodeTimestamp('2024-01-05T12:30:00Z')!.millisecondsSinceEpoch,
        expectedMillis,
      );
      // Offset shifts the instant.
      expect(
        parseEpisodeTimestamp(
          '2024-01-05T14:30:00+02:00',
        )!.millisecondsSinceEpoch,
        expectedMillis,
      );
      // Offset-less strings are read as local time.
      expect(
        parseEpisodeTimestamp('2024-01-05 12:30:00')!.millisecondsSinceEpoch,
        DateTime(2024, 1, 5, 12, 30).millisecondsSinceEpoch,
      );
      expect(
        parseEpisodeTimestamp('2024-01-05 12:30')!.millisecondsSinceEpoch,
        DateTime(2024, 1, 5, 12, 30).millisecondsSinceEpoch,
      );
      expect(
        parseEpisodeTimestamp('2024-01-05')!.millisecondsSinceEpoch,
        DateTime(2024, 1, 5).millisecondsSinceEpoch,
      );
      expect(
        parseEpisodeTimestamp(expectedMillis.toString())!.millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp(
          (expectedMillis / 1000).round().toString(),
        )!.millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp(
          'Fri, 5 Jan 2024 12:30:00 GMT',
        )!.millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp(
          'Fri, 5 Jan 2024 14:30:00 +0200',
        )!.millisecondsSinceEpoch,
        expectedMillis,
      );
    });

    test('rejects garbage', () {
      expect(parseEpisodeTimestamp(''), isNull);
      expect(parseEpisodeTimestamp('soon'), isNull);
      expect(parseEpisodeTimestamp('0'), isNull);
      expect(parseEpisodeTimestamp('12345'), isNull);
      expect(parseEpisodeTimestamp('2024-13-45'), isNull);
    });
  });

  group('predictNextRelease', () {
    test('weekly iso series', () {
      // Five Fridays, far enough in the past to never race DateTime.now().
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease(
        [for (var i = 0; i < 5; i++) _iso(start.add(_week * i))],
      )!;
      expect(p.interval, _week);
      expect(
        p.nextRelease.millisecondsSinceEpoch,
        start.add(_week * 5).millisecondsSinceEpoch,
      );
      expect(p.confidence, greaterThan(0.9));
      expect(p.sampleSize, 4);
    });

    test('mihon epoch millis, newest first', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final times = [
        for (var i = 3; i >= 0; i--) _millis(start.add(_week * i)),
      ];
      final p = predictNextRelease(times)!;
      expect(p.nextRelease, start.add(_week * 4));
    });

    test('epoch seconds', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final seconds = [
        for (var i = 0; i < 4; i++)
          start.add(_week * i).millisecondsSinceEpoch ~/ 1000,
      ];
      final p = predictNextRelease([
        for (final s in seconds) s.toString(),
      ])!;
      expect(p.interval, _week);
    });

    test('needs two distinct timestamps', () {
      expect(predictNextRelease(['2024-01-05', null, 'garbage']), isNull);
      expect(predictNextRelease(['2024-01-05', '2024-01-05']), isNull);
      expect(predictNextRelease(const []), isNull);
    });

    test('same-day batch drops do not shrink cadence', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        _millis(start),
        _millis(start.add(_week)),
        _millis(start.add(_week * 2)),
        _millis(start.add(_week * 2 + const Duration(hours: 3))),
        _millis(start.add(_week * 2 + const Duration(hours: 6))),
        _millis(start.add(_week * 2 + const Duration(hours: 9))),
      ])!;
      expect(p.interval, _week);
    });

    test('jitter snaps to weeks', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        _millis(start),
        _millis(start.add(_day * 8)),
        _millis(start.add(_day * 14)),
        _millis(start.add(_day * 23)),
        _millis(start.add(_day * 28)),
        _millis(start.add(_day * 36)),
      ])!;
      expect(p.interval, _week);
      expect(p.nextRelease, start.add(_day * 43));
      expect(p.confidence, allOf(greaterThan(0.2), lessThan(0.9)));
    });

    test('daily series stays daily', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        for (var i = 0; i < 10; i++) _millis(start.add(_day * i)),
      ])!;
      expect(p.interval, _day);
      expect(p.confidence, greaterThan(0.9));
    });

    test('monthly series is not snapped', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        for (var i = 0; i < 4; i++) _millis(start.add(_day * 30 * i)),
      ])!;
      expect(p.interval, _day * 30);
    });

    test('pre-announced episode is returned as is', () {
      final future = DateTime.now().add(_day * 3);
      final past = future.subtract(_week * 4);
      final p = predictNextRelease([
        _millis(past),
        _millis(past.add(_week)),
        _millis(past.add(_week * 2)),
        _millis(future),
      ])!;
      expect(
        p.nextRelease.millisecondsSinceEpoch,
        future.millisecondsSinceEpoch,
      );
      expect(p.confidence, greaterThanOrEqualTo(0.9));
    });

    test('outliers do not drag the median', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        _millis(start),
        _millis(start.add(_week)),
        _millis(start.add(_week * 2)),
        _millis(start.add(_week * 5)),
        _millis(start.add(_week * 6)),
        _millis(start.add(_week * 7)),
      ])!;
      expect(p.interval, _week);
    });

    test('absurd cadence is rejected', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1000000000000);
      expect(
        predictNextRelease([_millis(start), _millis(start.add(_day * 500))]),
        isNull,
      );
    });
  });
}
