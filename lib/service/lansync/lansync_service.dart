import 'dart:async';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/sync_client.dart';
import 'package:dionysos/service/lansync/sync_server.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/foundation.dart';
import 'package:metis/adapter/crdt.dart';

class LanSyncService extends ChangeNotifier {
  late final DeviceIdentity identity;
  late final PairingStore pairingStore;
  late final LanDiscovery discovery;
  late final LanSyncServer server;
  late final LanSyncClient client;

  bool _running = false;

  LanSyncService();

  static Future<void> ensureInitialized() async {
    final svc = LanSyncService();
    await svc._init();
    register<LanSyncService>(svc);
    logger.i('LAN sync service initialised');
  }

  Future<void> _init() async {
    await locateAsync<PreferenceService>();
    await locateAsync<Database>();

    identity = await DeviceIdentity.loadOrCreate(
      defaultName: settings.sync.lan.deviceName.value,
    );
    pairingStore = PairingStore();
    await pairingStore.load();

    // The sync repo comes from the CRDT adapter installed in Database.
    final db = locate<Database>();
    final crdt = db.db.getAdapter<CrdtAdapter>();
    final syncRepo = crdt.syncRepo;

    server = LanSyncServer(
      identity: identity,
      pairingStore: pairingStore,
      onPairingRequest: _onIncomingPairingRequest,
      syncRepo: syncRepo,
    );
    // When a pairing is added/removed on this side, rebuild the trust store so mTLS accepts the peer.
    server.onPairingChanged = server.restart;
    client = LanSyncClient(identity);

    // Bind the server first so we have a port to advertise.
    try {
      final port = await server.start();
      discovery = LanDiscovery(identity: identity, port: port);
    } catch (e) {
      logger.e('LAN sync: failed to start server', error: e);
      discovery = LanDiscovery(identity: identity, port: 0);
    }

    if (settings.sync.lan.enabled.value) {
      await enable();
    }
    pairingStore.addListener(_onPairingChanged);
  }

  bool get isRunning => _running;

  /// Enable advertising + (when the devices page is open) discovery.
  Future<void> enable() async {
    if (_running) return;
    _running = true;
    if (settings.sync.lan.discoverable.value) {
      await discovery.startAdvertising();
    }
    notifyListeners();
  }

  Future<void> disable() async {
    if (!_running) return;
    _running = false;
    await discovery.stopAdvertising();
    await discovery.stopScanning();
    notifyListeners();
  }

  Future<void> startScanning() => discovery.startScanning();

  Future<void> stopScanning() => discovery.stopScanning();

  /// Initiate pairing with a discovered peer (we act as A, the initiator).
  Future<bool> pairWith(DiscoveredPeer peer) async {
    try {
      final paired = await client.pairWith(
        DiscoveredPeerOrAddress.fromPeer(peer),
        _onInitiatorPrompt,
      );
      if (paired != null) {
        await pairingStore.add(paired);
        await server.restart();
        return true;
      }
      return false;
    } catch (e) {
      logger.e('LAN sync: pairing failed', error: e);
      return false;
    }
  }

  /// Remove a paired device and rebuild the trust store.
  Future<void> unpair(String deviceId) async {
    await pairingStore.remove(deviceId);
    await server.restart();
  }

  /// Sync with a paired device by id. Resolves the peer address from the
  /// current discovery results; if the peer isn't currently visible, the sync
  /// fails fast.
  Future<void> syncNow(
    String deviceId, {
    void Function(int, int)? onProgress,
  }) async {
    final paired = pairingStore.byId(deviceId);
    if (paired == null) {
      throw LanSyncException('not paired with $deviceId');
    }
    final peer = discovery.peers.value
        .where((p) => p.deviceId == deviceId)
        .firstOrNull;
    if (peer == null) {
      throw LanSyncException('device $deviceId not on the LAN');
    }
    final db = locate<Database>();
    final crdt = db.db.getAdapter<CrdtAdapter>();
    await client.syncWith(
      pairedDevice: paired,
      baseUrl: peer.httpUrl,
      syncRepo: crdt.syncRepo,
      onProgress: onProgress,
    );
    await pairingStore.markSynced(deviceId);
    notifyListeners();
  }

  /// Prompt shown on the *initiator* (A) after B has responded to /pair/init.
  Future<bool> _onInitiatorPrompt(
    DeviceInfo peerInfo,
    String peerFingerprint,
    String sas,
  ) => _showPairingDialog(peerInfo, peerFingerprint, sas);

  /// Prompt shown on the *responder* (B) when /pair/init arrives.
  Future<bool> _onIncomingPairingRequest(
    DeviceInfo peerInfo,
    String peerFingerprint,
    String sas,
  ) => _showPairingDialog(peerInfo, peerFingerprint, sas);

  Future<bool> _showPairingDialog(
    DeviceInfo peerInfo,
    String peerFingerprint,
    String sas,
  ) async {
    final showed = await showPairingConfirm(
      peerName: peerInfo.name,
      peerFingerprint: peerFingerprint,
      sasCode: sas,
    );
    return showed;
  }

  void _onPairingChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    pairingStore.removeListener(_onPairingChanged);
    discovery.dispose();
    server.stop();
    super.dispose();
  }

  /// Set by the UI layer (see [registerPairingDialog]) to a function that shows
  /// the [PairingConfirmDialog] via the global navigatorKey. This indirection
  /// keeps the service free of `flutter/widgets.dart` UI imports at the call
  /// site. Until registered, incoming pairing requests are declined.
  static Future<bool> Function({
    required String peerName,
    required String peerFingerprint,
    required String sasCode,
  })
  showPairingConfirm = _defaultShowPairingConfirm;

  static Future<bool> _defaultShowPairingConfirm({
    required String peerName,
    required String peerFingerprint,
    required String sasCode,
  }) async {
    logger.w(
      'LAN sync: pairing prompt arrived but no UI handler is registered '
      '(peer=$peerName). Declining.',
    );
    return false;
  }
}
