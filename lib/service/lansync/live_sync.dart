import 'dart:async';

import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/utils/debounce.dart';
import 'package:dionysos/utils/log.dart';
import 'package:metis/metis.dart';

/// A paired device that is currently reachable, with the address its sync
/// server was discovered on.
class OnlinePeer {
  final PairedDevice device;
  final String httpUrl;

  const OnlinePeer({required this.device, required this.httpUrl});

  String get deviceId => device.deviceId;
}

/// Pushes local database changes to online peers as they happen.
///
/// The CRDT change feed ([CrdtAdapter.watchChanges]) feeds a pending set that
/// is flushed after [debounce]: every pending record is pushed to each
/// currently online peer through [syncPeer], which applies the same
/// last-write-wins comparison as a batch sync — pushing a peer its own data
/// back is a no-op, so changes cannot echo between replicas. Changes made
/// while a peer is offline are not replayed by this loop; they are picked up
/// by the next batch sync (autosync or manual).
class LiveSync {
  /// Stream of locally changed record ids (CrdtAdapter.watchChanges).
  final Stream<DBRecord> changes;

  /// How long to collect changes before flushing.
  final Duration debounce;

  /// Currently reachable paired peers, resolved at flush time.
  final List<OnlinePeer> Function() onlinePeers;

  /// Pushes [records] to [peer]. Serialized against batch syncs by the
  /// owner's sync lock.
  final Future<void> Function(OnlinePeer peer, List<DBRecord> records) syncPeer;

  /// Serializes flushes against batch syncs.
  final Future<void> Function(Future<void> Function()) withLock;

  LiveSync({
    required this.changes,
    required this.debounce,
    required this.onlinePeers,
    required this.syncPeer,
    required this.withLock,
  });

  StreamSubscription<DBRecord>? _subscription;
  final Set<DBRecord> _pending = {};
  Debouncer? _debouncer;
  // A flush must never overlap itself: the debouncer can be flushed while a
  // flush from a previous run is still awaiting peers.
  Future<void> _flushing = Future.value();

  bool get isRunning => _subscription != null;

  void start() {
    if (_subscription != null) return;
    _debouncer = Debouncer(
      duration: debounce,
      action: () => unawaited(_flush()),
    );
    _subscription = changes.listen(
      (record) {
        _pending.add(record);
        _debouncer?.run();
      },
      onError: (Object e, StackTrace s) {
        // metis re-establishes the underlying live query on its own; the
        // pending set survives and the next change flushes it.
        logger.w('LAN sync: live change feed errored', error: e, stackTrace: s);
      },
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _debouncer?.dispose();
    _debouncer = null;
  }

  Future<void> _flush() async {
    final previous = _flushing;
    final completer = Completer<void>();
    _flushing = completer.future;
    await previous;
    try {
      // Peers are resolved before taking the snapshot: with none online the
      // changes stay queued for the next flush instead of being dropped.
      if (_pending.isEmpty) return;
      final peers = onlinePeers();
      if (peers.isEmpty) return;
      final pending = List<DBRecord>.of(_pending);
      // Records changed during the flush stay queued for the next one.
      _pending.removeAll(pending);
      await withLock(() async {
        for (final peer in peers) {
          try {
            await syncPeer(peer, pending);
          } catch (e, s) {
            logger.w(
              'LAN sync: live push to ${peer.device.name} failed',
              error: e,
              stackTrace: s,
            );
          }
        }
      });
    } finally {
      completer.complete();
    }
  }
}

/// Futures chained so that only one sync operation (batch or live flush)
/// runs at a time.
class SyncLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
