import 'dart:async';

import 'package:dionysos/service/lansync/live_sync.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metis/metis.dart';

void main() {
  const record = DBRecord('entry', 'r1');
  const other = DBRecord('entry', 'r2');

  OnlinePeer fakePeer(String id) => OnlinePeer(
    device: PairedDevice(deviceId: id, name: id, certPem: '', fingerprint: id),
    httpUrl: 'https://localhost:0',
  );

  LiveSync build(
    Stream<DBRecord> changes, {
    required List<OnlinePeer> Function() onlinePeers,
    required Future<void> Function(OnlinePeer, List<DBRecord>) syncPeer,
  }) {
    final lock = SyncLock();
    return LiveSync(
      changes: changes,
      debounce: const Duration(milliseconds: 20),
      onlinePeers: onlinePeers,
      syncPeer: syncPeer,
      withLock: lock.run,
    );
  }

  test('flushes changes to every online peer', () async {
    final controller = StreamController<DBRecord>();
    final pushed = <(String, DBRecord)>[];
    final live = build(
      controller.stream,
      onlinePeers: () => [fakePeer('a'), fakePeer('b')],
      syncPeer: (peer, records) async {
        for (final record in records) {
          pushed.add((peer.deviceId, record));
        }
      },
    )..start();

    controller.add(record);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    live.stop();
    expect(pushed, containsAll([('a', record), ('b', record)]));
  });

  test('deduplicates repeated changes to the same record', () async {
    final controller = StreamController<DBRecord>();
    final flushes = <List<DBRecord>>[];
    final live = build(
      controller.stream,
      onlinePeers: () => [fakePeer('a')],
      syncPeer: (_, records) async => flushes.add(records),
    )..start();

    controller
      ..add(record)
      ..add(record)
      ..add(record);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    live.stop();
    expect(flushes, hasLength(1));
    expect(flushes.single, [record]);
  });

  test('a failing peer does not prevent the others', () async {
    final controller = StreamController<DBRecord>();
    final pushedTo = <String>[];
    final live = build(
      controller.stream,
      onlinePeers: () => [fakePeer('broken'), fakePeer('good')],
      syncPeer: (peer, _) async {
        if (peer.deviceId == 'broken') throw Exception('offline');
        pushedTo.add(peer.deviceId);
      },
    )..start();

    controller.add(record);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    live.stop();
    expect(pushedTo, ['good']);
  });

  test('changes are kept pending while no peer is online', () async {
    final controller = StreamController<DBRecord>();
    var peersAvailable = false;
    final flushes = <List<DBRecord>>[];
    final live = build(
      controller.stream,
      onlinePeers: () => peersAvailable ? [fakePeer('a')] : const [],
      syncPeer: (_, records) async => flushes.add(records),
    )..start();

    controller.add(record);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(flushes, isEmpty);

    peersAvailable = true;
    controller.add(other);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    live.stop();
    // The next flush carries both the queued and the new record.
    expect(flushes, hasLength(1));
    expect(flushes.single.toSet(), {record, other});
  });

  test('stopped coordinator does not flush', () async {
    final controller = StreamController<DBRecord>();
    var flushed = false;
    final live = build(
      controller.stream,
      onlinePeers: () => [fakePeer('a')],
      syncPeer: (_, _) async => flushed = true,
    );
    live.start();
    live.stop();

    controller.add(record);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(flushed, isFalse);
  });
}
