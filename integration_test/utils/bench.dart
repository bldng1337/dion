import 'dart:math';

/// One measured benchmark: [name], sample count and latency statistics in
/// microseconds.
class BenchSample {
  final String name;
  final int count;
  final int min;
  final int max;
  final int mean;
  final int median;
  final int p95;

  const BenchSample({
    required this.name,
    required this.count,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p95,
  });
}

/// Runs [body] [iterations] times after one warmup round and collects latency
/// statistics per invocation. The warmup (and [setup]/[teardown] around every
/// measured run, e.g. to add the row a removal benchmark just deleted) keeps
/// each iteration operating on equivalent state.
Future<BenchSample> bench(
  String name,
  int iterations,
  Future<void> Function() body, {
  Future<void> Function()? setup,
  Future<void> Function()? teardown,
  bool warmup = true,
}) async {
  if (warmup) {
    await setup?.call();
    await body();
    await teardown?.call();
  }
  final times = <int>[];
  for (var i = 0; i < iterations; i++) {
    await setup?.call();
    final watch = Stopwatch()..start();
    await body();
    watch.stop();
    times.add(watch.elapsedMicroseconds);
    await teardown?.call();
  }
  times.sort();
  final total = times.fold<int>(0, (a, b) => a + b);
  return BenchSample(
    name: name,
    count: times.length,
    min: times.first,
    max: times.last,
    mean: total ~/ times.length,
    median: times[times.length ~/ 2],
    p95: times[min(times.length - 1, (times.length * 0.95).ceil() - 1)],
  );
}

/// Renders [samples] as an aligned table for the test log.
String formatBenchTable(Iterable<BenchSample> samples) {
  final rows = samples.toList();
  const columns = [
    ('benchmark', 34),
    ('n', 4),
    ('min', 10),
    ('median', 10),
    ('mean', 10),
    ('p95', 10),
    ('max', 10),
  ];
  final header = columns
      .map((c) => c.$1.padRight(c.$2))
      .join(' | ');
  final separator = columns.map((c) => '-' * c.$2).join('-+-');
  String us(int value) => '${(value / 1000).toStringAsFixed(2)}ms';
  final body = rows
      .map(
        (s) => [
          s.name.padRight(columns[0].$2),
          '${s.count}'.padLeft(columns[1].$2),
          us(s.min).padLeft(columns[2].$2),
          us(s.median).padLeft(columns[3].$2),
          us(s.mean).padLeft(columns[4].$2),
          us(s.p95).padLeft(columns[5].$2),
          us(s.max).padLeft(columns[6].$2),
        ].join(' | '),
      )
      .join('\n');
  return '\n$header\n$separator\n$body';
}
