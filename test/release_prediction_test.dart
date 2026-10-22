import 'package:dionysos/utils/release_prediction.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = Duration(days: 1);
const _week = Duration(days: 7);

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
        parseEpisodeTimestamp('2024-01-05T14:30:00+02:00')!
            .millisecondsSinceEpoch,
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
        parseEpisodeTimestamp(expectedMillis.toString())!
            .millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp((expectedMillis / 1000).round().toString())!
            .millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp('Fri, 5 Jan 2024 12:30:00 GMT')!
            .millisecondsSinceEpoch,
        expectedMillis,
      );
      expect(
        parseEpisodeTimestamp('Fri, 5 Jan 2024 14:30:00 +0200')!
            .millisecondsSinceEpoch,
        expectedMillis,
      );
      // Temporal.ZonedDateTime annotation is stripped.
      expect(
        parseEpisodeTimestamp('2024-01-05T14:30:00+02:00[Europe/Berlin]')!
            .millisecondsSinceEpoch,
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
    // Sources hand over parsed DateTimes since the runtime update; the
    // string forms they emit are covered by the parseEpisodeTimestamp tests.
    test('weekly series', () {
      // Far enough in the past to never race DateTime.now().
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        for (var i = 0; i < 5; i++) start.add(_week * i),
      ])!;
      expect(p.interval, _week);
      expect(
        p.nextRelease.millisecondsSinceEpoch,
        start.add(_week * 5).millisecondsSinceEpoch,
      );
      expect(p.confidence, greaterThan(0.9));
      expect(p.sampleSize, 4);
    });

    test('unsorted input is ordered internally', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final times = [for (var i = 3; i >= 0; i--) start.add(_week * i)];
      final p = predictNextRelease(times)!;
      expect(p.nextRelease, start.add(_week * 4));
    });

    test('needs two distinct timestamps', () {
      final t = _utc(2024, 1, 5);
      expect(predictNextRelease([t, null]), isNull);
      expect(predictNextRelease([t, t]), isNull);
      expect(predictNextRelease([null, null]), isNull);
      expect(predictNextRelease(const []), isNull);
    });

    test('duplicate instants collapse to one release', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        start,
        start,
        start.add(_week),
        start.add(_week),
      ])!;
      expect(p.interval, _week);
    });

    test('same-day batch drops do not shrink cadence', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        start,
        start.add(_week),
        start.add(_week * 2),
        start.add(_week * 2 + const Duration(hours: 3)),
        start.add(_week * 2 + const Duration(hours: 6)),
        start.add(_week * 2 + const Duration(hours: 9)),
      ])!;
      expect(p.interval, _week);
    });

    test('jitter snaps to weeks', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        start,
        start.add(_day * 8),
        start.add(_day * 14),
        start.add(_day * 23),
        start.add(_day * 28),
        start.add(_day * 36),
      ])!;
      expect(p.interval, _week);
      expect(p.nextRelease, start.add(_day * 43));
      expect(p.confidence, allOf(greaterThan(0.2), lessThan(0.9)));
    });

    test('daily series stays daily', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        for (var i = 0; i < 10; i++) start.add(_day * i),
      ])!;
      expect(p.interval, _day);
      expect(p.confidence, greaterThan(0.9));
    });

    test('monthly series is not snapped', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1600000000000);
      final p = predictNextRelease([
        for (var i = 0; i < 4; i++) start.add(_day * 30 * i),
      ])!;
      expect(p.interval, _day * 30);
    });

    test('pre-announced episode is returned as is', () {
      final future = DateTime.now().add(_day * 3);
      final past = future.subtract(_week * 4);
      final p = predictNextRelease([
        past,
        past.add(_week),
        past.add(_week * 2),
        future,
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
        start,
        start.add(_week),
        start.add(_week * 2),
        start.add(_week * 5),
        start.add(_week * 6),
        start.add(_week * 7),
      ])!;
      expect(p.interval, _week);
    });

    test('absurd cadence is rejected', () {
      final start = DateTime.fromMillisecondsSinceEpoch(1000000000000);
      expect(predictNextRelease([start, start.add(_day * 500)]), isNull);
    });
  });

  group('repairLegacyTimestamps', () {
    test('rewrites legacy episode timestamps to ISO', () {
      final json = {
        'entry': {
          'episodes': [
            {'id': 'a', 'timestamp': 'Fri, 5 Jan 2024 12:30:00 GMT'},
            {'id': 'b', 'timestamp': '1704457800'},
            {'id': 'c', 'timestamp': '2024-01-05T12:30:00Z'},
          ],
        },
      };
      expect(repairLegacyTimestamps(json), isTrue);
      final episodes =
          (json['entry']! as Map)['episodes'] as List<Map<dynamic, dynamic>>;
      expect(episodes[0]['timestamp'], '2024-01-05T12:30:00.000Z');
      expect(episodes[1]['timestamp'], '2024-01-05T12:30:00.000Z');
      expect(episodes[2]['timestamp'], '2024-01-05T12:30:00.000Z');
    });

    test('normalizes both entry and original copies', () {
      final json = {
        'original': {
          'episodes': [
            {'timestamp': '2024-01-05T12:30:00Z'},
          ],
        },
        'entryExtensions': [
          {
            'ui': {
              'type': 'Timestamp',
              'timestamp': '2024-01-05T14:30:00+02:00',
            },
          },
        ],
      };
      expect(repairLegacyTimestamps(json), isTrue);
      final original = json['original']! as Map;
      final episodes = original['episodes']! as List;
      expect(episodes.single['timestamp'], '2024-01-05T12:30:00.000Z');
      final ui = (json['entryExtensions']! as List).single as Map;
      expect((ui['ui'] as Map)['timestamp'], '2024-01-05T12:30:00.000Z');
    });

    test('drops unparseable episode timestamps', () {
      final json = {
        'entry': {
          'episodes': [
            {'id': 'a', 'timestamp': 'soon(tm)'},
          ],
        },
      };
      expect(repairLegacyTimestamps(json), isTrue);
      expect(
        ((json['entry']! as Map)['episodes'] as List).single.containsKey(
          'timestamp',
        ),
        isFalse,
      );
    });

    test('degrades unparseable custom-ui timestamps to text', () {
      final json = {
        'entry': {
          'ui': {
            'type': 'Timestamp',
            'timestamp': 'whenever',
            'display': {'type': 'relative'},
          },
        },
      };
      expect(repairLegacyTimestamps(json), isTrue);
      final ui = (json['entry']! as Map)['ui'] as Map;
      expect(ui['type'], 'Text');
      expect(ui['text'], 'whenever');
      expect(ui.containsKey('timestamp'), isFalse);
    });

    test('untouched rows report no change', () {
      final json = {
        'entry': {
          'episodes': [
            {'id': 'a'},
            {'id': 'b', 'timestamp': null},
          ],
          'lastRefreshed': '2024-01-05T12:30:00.000Z',
        },
      };
      expect(repairLegacyTimestamps(json), isFalse);
    });
  });
}
