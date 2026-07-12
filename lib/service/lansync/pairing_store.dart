import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPairedKey = 'lan.paired';

class PairedDevice {
  final String deviceId;
  final String name;
  final String certPem;
  final String fingerprint;
  final DateTime? lastSyncedAt;

  const PairedDevice({
    required this.deviceId,
    required this.name,
    required this.certPem,
    required this.fingerprint,
    this.lastSyncedAt,
  });

  PairedDevice copyWith({String? name, DateTime? lastSyncedAt}) => PairedDevice(
    deviceId: deviceId,
    name: name ?? this.name,
    certPem: certPem,
    fingerprint: fingerprint,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'certPem': certPem,
    'fingerprint': fingerprint,
    if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
    deviceId: json['deviceId'] as String,
    name: json['name'] as String,
    certPem: json['certPem'] as String,
    fingerprint: json['fingerprint'] as String,
    lastSyncedAt: json['lastSyncedAt'] == null
        ? null
        : DateTime.parse(json['lastSyncedAt'] as String),
  );
}

class PairingStore extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  List<PairedDevice> _devices = const [];

  PairingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  List<PairedDevice> get devices => List.unmodifiable(_devices);

  Iterable<String> get trustedCertPems => _devices.map((d) => d.certPem);

  bool containsFingerprint(String fingerprint) =>
      _devices.any((d) => d.fingerprint == fingerprint);

  PairedDevice? byId(String deviceId) {
    for (final d in _devices) {
      if (d.deviceId == deviceId) return d;
    }
    return null;
  }

  Future<void> load() async {
    final raw = await _storage.read(key: _kPairedKey);
    if (raw == null) {
      _devices = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _devices = list
          .map((e) => PairedDevice.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      _devices = const [];
    }
    notifyListeners();
  }

  Future<void> add(PairedDevice device) async {
    _devices = [
      ..._devices.where((d) => d.deviceId != device.deviceId),
      device,
    ];
    await _persist();
  }

  Future<void> remove(String deviceId) async {
    _devices = _devices.where((d) => d.deviceId != deviceId).toList();
    await _persist();
  }

  Future<void> markSynced(String deviceId) async {
    var changed = false;
    _devices = _devices.map((d) {
      if (d.deviceId == deviceId) {
        changed = true;
        return d.copyWith(lastSyncedAt: DateTime.now());
      }
      return d;
    }).toList();
    if (changed) await _persist();
  }

  Future<void> _persist() async {
    await _storage.write(
      key: _kPairedKey,
      value: jsonEncode(_devices.map((d) => d.toJson()).toList()),
    );
    notifyListeners();
  }
}
