import 'dart:convert';
import 'dart:io';

import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';

class DiscoveredPeer {
  final String deviceId;
  final String name;
  final int protocolVersion;
  final String fingerprint;
  final InternetAddress address;
  final int port;

  const DiscoveredPeer({
    required this.deviceId,
    required this.name,
    required this.protocolVersion,
    required this.fingerprint,
    required this.address,
    required this.port,
  });

  String get httpUrl => 'https://${address.address}:$port';

  @override
  bool operator ==(Object other) =>
      other is DiscoveredPeer && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

class LanDiscovery {
  final DeviceIdentity _identity;
  final int port;

  Registration? _registration;
  bool _advertising = false;

  Discovery? _discovery;
  bool _scanning = false;

  final ValueNotifier<List<DiscoveredPeer>> peers =
      ValueNotifier<List<DiscoveredPeer>>(const []);

  LanDiscovery({required DeviceIdentity identity, required this.port})
    : _identity = identity;

  bool get isAdvertising => _advertising;

  /// Begin advertising the dion sync service on the LAN.
  Future<void> startAdvertising() async {
    if (_advertising) return;
    final txt = <String, Uint8List?>{
      MdnsTxt.id: utf8.encode(_identity.deviceId),
      MdnsTxt.name: utf8.encode(_identity.name),
      MdnsTxt.pv: utf8.encode('$dionSyncProtocolVersion'),
      MdnsTxt.fp: utf8.encode(_identity.fingerprint),
    };
    try {
      _registration = await register(
        Service(
          name: _identity.name,
          type: dionSyncMdnsService,
          port: port,
          txt: txt,
        ),
      );
      _advertising = true;
      logger.i('LAN sync: advertising $_identity.name on port $port');
    } catch (e) {
      logger.e('LAN sync: failed to start advertising', error: e);
      _registration = null;
      _advertising = false;
    }
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    _advertising = false;
    final registration = _registration;
    _registration = null;
    if (registration == null) return;
    try {
      await unregister(registration);
    } catch (e) {
      logger.w('LAN sync: error stopping registration', error: e);
    }
  }

  /// Start continuous (event-driven) discovery. Discovered services are mirrored
  /// into [peers] as the platform reports them; no polling timer is needed.
  Future<void> startScanning() async {
    if (_scanning) return;
    _scanning = true;
    try {
      _discovery = await startDiscovery(
        dionSyncMdnsService,
        ipLookupType: IpLookupType.any,
      );
      _discovery!.addListener(_onDiscoveryChanged);
      // Seed from any services already collected.
      _onDiscoveryChanged();
    } catch (e) {
      logger.w('LAN sync: failed to start discovery', error: e);
      _scanning = false;
      _discovery = null;
    }
  }

  Future<void> stopScanning() async {
    if (!_scanning) return;
    _scanning = false;
    final discovery = _discovery;
    _discovery = null;
    if (discovery == null) return;
    discovery.removeListener(_onDiscoveryChanged);
    try {
      await stopDiscovery(discovery);
    } catch (e) {
      logger.w('LAN sync: error stopping discovery', error: e);
    }
    peers.value = const [];
  }

  void _onDiscoveryChanged() {
    final discovery = _discovery;
    if (discovery == null) return;
    final byId = <String, DiscoveredPeer>{};
    for (final service in discovery.services) {
      final peer = _parseService(service);
      if (peer == null) continue;
      if (peer.deviceId == _identity.deviceId) continue; // ignore self
      byId[peer.deviceId] = peer;
    }
    peers.value = byId.values.toList(growable: false);
  }

  DiscoveredPeer? _parseService(Service service) {
    final txt = service.txt;
    if (txt == null) return null;
    final id = _txtString(txt, MdnsTxt.id);
    final name = _txtString(txt, MdnsTxt.name) ?? service.name;
    final pv = int.tryParse(_txtString(txt, MdnsTxt.pv) ?? '') ?? 0;
    final fp = _txtString(txt, MdnsTxt.fp) ?? '';
    final addr = service.addresses?.isEmpty == false
        ? service.addresses!.first
        : null;
    final port = service.port;
    if (id == null || addr == null || port == null || port == 0) return null;
    return DiscoveredPeer(
      deviceId: id,
      name: name ?? 'unknown',
      protocolVersion: pv,
      fingerprint: fp,
      address: addr,
      port: port,
    );
  }

  String? _txtString(Map<String, Uint8List?> txt, String key) {
    final value = txt[key];
    if (value == null) return null;
    try {
      return utf8.decode(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();
    peers.dispose();
  }
}
