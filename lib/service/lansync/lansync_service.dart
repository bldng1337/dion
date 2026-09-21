import 'dart:async';

import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/live_sync.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/sync_client.dart';
import 'package:dionysos/service/lansync/sync_server.dart';
import 'package:dionysos/service/mock_extension.dart';
import 'package:dionysos/service/mock_tracker_extension.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/utils/debounce.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/version.dart';
import 'package:flutter/foundation.dart';
import 'package:metis/metis.dart';
import 'package:pub_semver/pub_semver.dart';

class LanSyncService extends ChangeNotifier {
  late final DeviceIdentity identity;
  late final PairingStore pairingStore;
  late final LanDiscovery discovery;
  late final LanSyncServer server;
  late final LanSyncClient client;
  late final LiveSync liveSync;

  bool _running = false;
  final SyncLock _syncLock = SyncLock();
  int _scanHolds = 0;
  Debouncer? _autoSyncDebouncer;

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
    server.extensionLister = listInstalledExtensions;
    server.extensionInstaller = installExtensionFromLocation;
    client = LanSyncClient(identity);

    // Bind the server first so we have a port to advertise.
    try {
      final port = await server.start();
      discovery = LanDiscovery(identity: identity, port: port);
    } catch (e) {
      logger.e('LAN sync: failed to start server', error: e);
      discovery = LanDiscovery(identity: identity, port: 0);
    }

    liveSync = LiveSync(
      changes: crdt.watchChanges(),
      debounce: const Duration(milliseconds: 500),
      onlinePeers: onlinePeers,
      syncPeer: _syncRecordsToPeer,
      withLock: _syncLock.run,
    );

    // Callers of the settings toggles expect an immediate effect; no post
    // frame hop and no initial fire (enable() below applies the startup state).
    Observer(
      _updateLiveSync,
      settings.sync.lan.livesync,
      callOnInit: false,
      callIndirectly: false,
    );
    Observer(
      () {
        _autoSyncDebouncer?.cancel();
        _scheduleAutoSync();
      },
      settings.sync.lan.autoSync,
      callOnInit: false,
      callIndirectly: false,
    );
    Observer(
      _onPeersChanged,
      discovery.peers,
      callOnInit: false,
      callIndirectly: false,
    );

    if (settings.sync.lan.enabled.value) {
      await enable();
    }
    pairingStore.addListener(_onPairingChanged);
  }

  bool get isRunning => _running;

  /// Enable advertising + continuous discovery. Discovery stays on while the
  /// service is enabled: online status, autosync and live sync all resolve
  /// peers through it, not just the devices page.
  Future<void> enable() async {
    if (_running) return;
    _running = true;
    if (settings.sync.lan.discoverable.value) {
      await discovery.startAdvertising();
    }
    await _holdScanning();
    _updateLiveSync();
    notifyListeners();
  }

  Future<void> disable() async {
    if (!_running) return;
    _running = false;
    liveSync.stop();
    _autoSyncDebouncer?.cancel();
    await discovery.stopAdvertising();
    await _releaseScanning();
    notifyListeners();
  }

  /// Whether [deviceId] is currently visible on the LAN.
  bool isOnline(String deviceId) =>
      discovery.peers.value.any((p) => p.deviceId == deviceId);

  /// All paired devices that are currently visible on the LAN.
  List<OnlinePeer> onlinePeers() => [
    for (final p in discovery.peers.value)
      if (pairingStore.byId(p.deviceId) case final PairedDevice paired)
        OnlinePeer(device: paired, httpUrl: p.httpUrl),
  ];

  /// Discovery is refcounted: the devices page and the enabled service each
  /// hold it open, scanning stops only when the last hold is released.
  Future<void> startScanning() => _holdScanning();

  Future<void> stopScanning() => _releaseScanning();

  Future<void> _holdScanning() async {
    _scanHolds++;
    await discovery.startScanning();
  }

  Future<void> _releaseScanning() async {
    _scanHolds--;
    if (_scanHolds <= 0) {
      _scanHolds = 0;
      await discovery.stopScanning();
    }
  }

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
        // The freshly paired device is usually still online; converge now.
        _scheduleAutoSync();
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
    await _syncDeviceNow(
      OnlinePeer(device: paired, httpUrl: peer.httpUrl),
      onProgress: onProgress,
    );
    notifyListeners();
  }

  /// Batch sync (database) followed by an extension exchange, serialized
  /// against other syncs and live flushes.
  Future<void> _syncDeviceNow(
    OnlinePeer peer, {
    void Function(int, int)? onProgress,
  }) async {
    final db = locate<Database>();
    final crdt = db.db.getAdapter<CrdtAdapter>();
    await _syncLock.run(() async {
      await client.syncWith(
        pairedDevice: peer.device,
        baseUrl: peer.httpUrl,
        syncRepo: crdt.syncRepo,
        onProgress: onProgress,
      );
      await pairingStore.markSynced(peer.deviceId);
      await _syncExtensions(peer);
    });
    notifyListeners();
  }

  /// Live path: push the given records to [peer] with per-record
  /// last-write-wins comparison.
  Future<void> _syncRecordsToPeer(
    OnlinePeer peer,
    List<DBRecord> records,
  ) async {
    final db = locate<Database>();
    final crdt = db.db.getAdapter<CrdtAdapter>();
    final remote = client.remoteRepoFor(
      pairedDevice: peer.device,
      baseUrl: peer.httpUrl,
    );
    try {
      for (final record in records) {
        await crdt.syncRepo.syncRecord(remote, record);
      }
    } finally {
      remote.dispose();
    }
  }

  /// Mirrors extension installations with a paired peer: installs on this
  /// device what the peer has that we don't (or has in a newer version), and
  /// asks the peer to do the same for ours. Best-effort — a peer without
  /// extension sync support or with an unusable location must not fail the
  /// database sync this runs after.
  Future<void> _syncExtensions(OnlinePeer peer) async {
    final ours = await listInstalledExtensions();
    try {
      final theirs = await client.fetchPeerExtensions(
        pairedDevice: peer.device,
        baseUrl: peer.httpUrl,
      );
      final oursById = {for (final e in ours) e.id: e};
      for (final info in theirs) {
        if (_needsInstall(info, oursById[info.id])) {
          logger.i(
            'LAN sync: installing extension ${info.id} shared by ${peer.device.name}',
          );
          await installExtensionFromLocation(info.url);
        }
      }
      final theirsById = {for (final e in theirs) e.id: e};
      for (final info in ours) {
        if (_needsInstall(info, theirsById[info.id])) {
          await client.installPeerExtension(
            pairedDevice: peer.device,
            baseUrl: peer.httpUrl,
            info: info,
          );
        }
      }
    } catch (e, st) {
      logger.w(
        'LAN sync: extension exchange with ${peer.device.name} failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  bool _needsInstall(ExtensionSyncInfo info, ExtensionSyncInfo? current) {
    if (info.url.isEmpty) return false;
    if (current == null || current.url.isEmpty) return true;
    // Only upgrade on a strictly newer version; without comparable versions
    // (e.g. sideloaded extensions) leave the installation alone.
    final theirs = _tryParseVersion(info.version);
    final mine = _tryParseVersion(current.version);
    if (theirs == null || mine == null) return false;
    return theirs > mine;
  }

  Version? _tryParseVersion(String version) {
    try {
      return parseVersion(version);
    } catch (_) {
      return null;
    }
  }

  /// Listed for the local `/extensions/list` sync route.
  Future<List<ExtensionSyncInfo>> listInstalledExtensions() async {
    if (!has<ExtensionService>()) return const [];
    final debugMocks = {MockExtension.mockId, MockTrackerExtension.mockId};
    return [
      for (final ext in locate<ExtensionService>().getExtensions())
        if (!debugMocks.contains(ext.id) && ext.data.url.isNotEmpty)
          ExtensionSyncInfo(
            id: ext.id,
            name: ext.data.name,
            version: ext.data.version,
            url: ext.data.url,
            repo: ext.data.repo,
          ),
    ];
  }

  /// Wired to the local `/extensions/install` sync route.
  Future<void> installExtensionFromLocation(String location) {
    return locate<ExtensionService>().install(location);
  }

  void _onPeersChanged() {
    // Online indicators in the devices view react to discovery churn.
    notifyListeners();
    _scheduleAutoSync();
  }

  /// Runs one batch sync covering every currently online paired device,
  /// debounced so mDNS churn does not trigger a sync storm.
  void _scheduleAutoSync() {
    if (!_running || !settings.sync.lan.autoSync.value) return;
    if (onlinePeers().isEmpty) return;
    _autoSyncDebouncer ??= Debouncer(
      duration: const Duration(seconds: 2),
      action: () => unawaited(_autoSyncOnlinePeers()),
    );
    _autoSyncDebouncer!.run();
  }

  Future<void> _autoSyncOnlinePeers() async {
    if (!_running || !settings.sync.lan.autoSync.value) return;
    for (final peer in onlinePeers()) {
      try {
        await _syncDeviceNow(peer);
      } catch (e, st) {
        logger.w(
          'LAN sync: automatic sync with ${peer.device.name} failed',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void _updateLiveSync() {
    if (_running && settings.sync.lan.livesync.value) {
      liveSync.start();
    } else {
      liveSync.stop();
    }
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
    liveSync.stop();
    _autoSyncDebouncer?.dispose();
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
