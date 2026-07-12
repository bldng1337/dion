import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _kIdKey = 'lan.identity.id';
const _kNameKey = 'lan.identity.name';
const _kCertKey = 'lan.identity.cert';
const _kPrivKeyKey = 'lan.identity.privkey';

class DeviceIdentity {
  final String deviceId;
  final String name;
  final String certPem;
  final String privateKeyPem;
  final String fingerprint;

  DeviceIdentity({
    required this.deviceId,
    required this.name,
    required this.certPem,
    required this.privateKeyPem,
    required this.fingerprint,
  });

  DeviceInfo toInfo() => DeviceInfo(
    deviceId: deviceId,
    name: name,
    protocolVersion: dionSyncProtocolVersion,
    certPem: certPem,
    fingerprint: fingerprint,
  );

  SecurityContext buildContext({Iterable<String> trustedCertPems = const []}) {
    // withTrustedRoots: false so only paired peer certs (added below) are
    // trusted for mTLS the system root store must not be consulted.
    // ignore: avoid_redundant_argument_values
    final context = SecurityContext(withTrustedRoots: false);
    context.useCertificateChainBytes(utf8.encode(certPem));
    context.usePrivateKeyBytes(utf8.encode(privateKeyPem), password: '');
    for (final pem in trustedCertPems) {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
    }
    return context;
  }

  static Future<DeviceIdentity> loadOrCreate({
    FlutterSecureStorage? storage,
    String? defaultName,
  }) async {
    final s = storage ?? const FlutterSecureStorage();
    final existingCert = await s.read(key: _kCertKey);
    if (existingCert != null) {
      final id = await s.read(key: _kIdKey) ?? const Uuid().v4();
      final name =
          await s.read(key: _kNameKey) ?? defaultName ?? _defaultName();
      final priv = (await s.read(key: _kPrivKeyKey))!;
      return DeviceIdentity(
        deviceId: id,
        name: name,
        certPem: existingCert,
        privateKeyPem: priv,
        fingerprint: fingerprintOf(existingCert),
      );
    }

    // First run: generate a fresh self-signed identity.
    final pair = CryptoUtils.generateRSAKeyPair();
    final priv = pair.privateKey as RSAPrivateKey;
    final pub = pair.publicKey as RSAPublicKey;
    final id = const Uuid().v4();
    final name = defaultName ?? _defaultName();
    final csr = X509Utils.generateRsaCsrPem({'CN': id}, priv, pub);
    // 10 years — identity is long-lived; pairing can be revoked anytime.
    final certPem = X509Utils.generateSelfSignedCertificate(priv, csr, 3650);
    final privPem = CryptoUtils.encodeRSAPrivateKeyToPem(priv);

    await s.write(key: _kIdKey, value: id);
    await s.write(key: _kNameKey, value: name);
    await s.write(key: _kCertKey, value: certPem);
    await s.write(key: _kPrivKeyKey, value: privPem);

    return DeviceIdentity(
      deviceId: id,
      name: name,
      certPem: certPem,
      privateKeyPem: privPem,
      fingerprint: fingerprintOf(certPem),
    );
  }

  static Future<void> saveName(
    String name, {
    FlutterSecureStorage? storage,
  }) async {
    final s = storage ?? const FlutterSecureStorage();
    await s.write(key: _kNameKey, value: name);
  }
}

String fingerprintOf(String certPem) {
  final der = CryptoUtils.getBytesFromPEMString(certPem);
  return CryptoUtils.getHash(der);
}

String _defaultName() => Platform.localHostname;
