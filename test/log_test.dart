import 'dart:io';

import 'package:dionysos/utils/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

LogEvent _event(
  String message, {
  Level level = Level.info,
  Object? error,
  StackTrace? stackTrace,
  DateTime? time,
}) =>
    LogEvent(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
      time: time ?? DateTime(2026, 1, 1, 12),
    );

void main() {
  late Directory dir;
  final stores = <LogStore>[];

  // Windows keeps handles open until closed; tearDown deletes the directory,
  // so every store created by a test must be registered here.
  LogStore spawnStore({int rotateBytes = 512 * 1024}) {
    final store = LogStore(rotateBytes: rotateBytes);
    stores.add(store);
    return store;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dion_logs');
  });

  tearDown(() async {
    for (final store in stores) {
      await store.close();
    }
    stores.clear();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('LogRecord map round trip', () {
    final record = LogRecord.fromEvent(
      _event(
        'boom',
        level: Level.error,
        error: 'the error',
        stackTrace: StackTrace.current,
      ),
      source: kLogSourceBackground,
    );
    final parsed = LogRecord.fromMap(record.toMap());
    expect(parsed, record);
  });

  test('records survive a restart', () async {
    final store = spawnStore();
    await store.init(dir);
    store.add(_event('first'));
    store.add(_event('second', level: Level.warning));
    await store.flushed;
    await store.close();

    final reopened = spawnStore();
    await reopened.init(dir);
    expect(reopened.records.map((r) => r.message), ['first', 'second']);
    expect(reopened.records[1].level, Level.warning);
  });

  test('records logged before init are flushed once ready', () async {
    final store = spawnStore();
    store.add(_event('early'));
    await store.init(dir);
    await store.flushed;

    final file = File('${dir.path}/dion.log');
    expect(await file.exists(), true);
    expect(await file.readAsLines(), isNotEmpty);
    expect(store.records.single.message, 'early');

    final reopened = spawnStore();
    await reopened.init(dir);
    expect(reopened.records.map((r) => r.message), ['early']);
  });

  test('background isolate records are tagged and appended per write',
      () async {
    final store = spawnStore()..source = kLogSourceBackground;
    await store.init(dir);
    store.add(_event('from bg', level: Level.error, error: 'job failed'));
    await store.flushed;

    final reopened = spawnStore();
    await reopened.init(dir);
    final record = reopened.records.single;
    expect(record.source, kLogSourceBackground);
    expect(record.error, 'job failed');

    final formatted = formatLogRecord(record);
    expect(formatted, contains('[BACKGROUND]'));
    expect(formatted, contains('Error: job failed'));
    expect(formatted, contains('---'));
  });

  test('rotation moves the current file and keeps history loadable',
      () async {
    final store = spawnStore(rotateBytes: 200);
    await store.init(dir);
    for (var i = 0; i < 20; i++) {
      store.add(_event('message $i with some padding to fill the file'));
    }
    await store.flushed;
    await store.close();

    final rotated = File('${dir.path}/dion.log.1');
    expect(await rotated.exists(), true);
    expect(await rotated.length(), greaterThan(0));

    final reopened = spawnStore(rotateBytes: 200);
    await reopened.init(dir);
    final messages = reopened.records.map((r) => r.message).toList();
    // Retention is size-bounded, so the oldest records may have rotated out;
    // what must hold is that history loads from more than just the current
    // file, in order, up to the newest record.
    final currentFileLines =
        await File('${dir.path}/dion.log').readAsLines();
    expect(reopened.records.length, greaterThan(currentFileLines.length));
    expect(messages.last, 'message 19 with some padding to fill the file');
    final indexes = messages
        .map((message) => int.parse(message.split(' ')[1]))
        .toList();
    expect(indexes, equals(indexes.toList()..sort()));
  });

  test('clear wipes files and memory', () async {
    final store = spawnStore();
    await store.init(dir);
    store.add(_event('gone soon'));
    await store.flushed;

    await store.clear();
    await store.flushed;

    expect(store.records, isEmpty);
    expect(await File('${dir.path}/dion.log').exists(), false);
    expect(await File('${dir.path}/dion.log.1').exists(), false);

    store.add(_event('after clear'));
    await store.flushed;
    expect(store.records.map((r) => r.message), ['after clear']);
  });
}
