import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/signing.dart';
import 'package:dionysos/service/lansync/sync_client.dart';
import 'package:dionysos/service/lansync/sync_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metis/adapter/sync/repo.dart';
import 'package:metis/metis.dart';

/// In-memory [PairingKeyValueStore] so tests avoid platform channels.
class _MemoryStore implements PairingKeyValueStore {
  final Map<String, String> _map = {};
  @override
  Future<String?> read({required String key}) async => _map[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      _map[key] = value;
  @override
  Future<void> delete({required String key}) async => _map.remove(key);
}

/// Minimal [SyncRepo] that records calls; enough for [LanSyncServer] to start.
/// Extends [SyncRepo] to inherit its concrete `sync` implementation.
class _FakeSyncRepo extends SyncRepo {
  @override
  Future<SyncRepoData> getSyncPointData() async => const SyncRepoData(
        tables: {},
        version: 1,
        entries: 0,
      );
  @override
  Stream<SyncData> querySyncData(int offset, int limit) async* {}
  @override
  Future<SyncData?> getSyncData(DBRecord id) async => null;
  @override
  Future<dynamic> pull(SyncData meta) async => null;
  @override
  Future<void> push(SyncData meta, Object? data) async {}
}

/// Build a [DeviceIdentity] in-process without touching platform storage.
DeviceIdentity _makeIdentity(String name) {
  final pair = CryptoUtils.generateRSAKeyPair();
  final priv = pair.privateKey as RSAPrivateKey;
  final pub = pair.publicKey as RSAPublicKey;
  final id = name;
  final csr = X509Utils.generateRsaCsrPem({'CN': id}, priv, pub);
  final certPem = X509Utils.generateSelfSignedCertificate(priv, csr, 3650);
  final privPem = CryptoUtils.encodeRSAPrivateKeyToPem(priv);
  return DeviceIdentity(
    deviceId: id,
    name: name,
    certPem: certPem,
    privateKeyPem: privPem,
    fingerprint: fingerprintOf(certPem),
  );
}

void main() {
  group('signing helpers', () {
    test('sign/verify roundtrip over canonical pairing TBS', () {
      final id = _makeIdentity('signer');
      final info = id.toInfo();
      final tbs = canonicalPairingTbs(info);
      final sig = signPayload(id.privateKeyPem, tbs);
      expect(verifyPayload(id.certPem, tbs, sig), isTrue);
    });

    test('verification fails for tampered data', () {
      final id = _makeIdentity('signer');
      final info = id.toInfo();
      final tbs = canonicalPairingTbs(info);
      final sig = signPayload(id.privateKeyPem, tbs);
      final tampered = Uint8List.fromList([...tbs, 1]);
      expect(verifyPayload(id.certPem, tampered, sig), isFalse);
    });

    test('verification fails for a foreign cert', () {
      final a = _makeIdentity('a');
      final b = _makeIdentity('b');
      final tbs = canonicalPairingTbs(a.toInfo());
      final sig = signPayload(a.privateKeyPem, tbs);
      expect(verifyPayload(b.certPem, tbs, sig), isFalse);
    });

    test('verification never throws on malformed input', () {
      expect(verifyPayload('not a cert', Uint8List(0), 'xx'), isFalse);
    });
  });

  group('pairing handshake (loopback TLS)', () {
    late DeviceIdentity initiator;
    late DeviceIdentity responder;
    late PairingStore responderStore;
    late LanSyncServer server;
    late int port;

    setUp(() async {
      initiator = _makeIdentity('initiator');
      responder = _makeIdentity('responder');
      responderStore = PairingStore(storage: _MemoryStore());
      await responderStore.load();
      server = LanSyncServer(
        identity: responder,
        pairingStore: responderStore,
        onPairingRequest: (_, _, _) async => true,
        syncRepo: _FakeSyncRepo(),
      );
      // onPairingChanged triggers restart(); wire it up like the service does.
      server.onPairingChanged = server.restart;
      port = await server.start(address: InternetAddress.loopbackIPv4);
    });

    tearDown(() async {
      await server.stop();
    });

    test('happy path: pairWithoutClientCert completes and persists', () async {
      final client = LanSyncClient(initiator);
      final paired = await client.pairWith(
        DiscoveredPeerOrAddress.fromAddress(
          InternetAddress.loopbackIPv4,
          port,
        ),
        (_, _, _) async => true,
      );
      expect(paired, isNotNull);
      expect(paired!.deviceId, responder.deviceId);
      // The fingerprint the initiator recorded is the responder's real cert fp.
      expect(paired.fingerprint, responder.fingerprint);
      // The responder stores the initiator's cert fingerprint (the peer).
      expect(
        responderStore.containsFingerprint(initiator.fingerprint),
        isTrue,
      );
    });

    test('responder rejects an invalid signature with 403', () async {
      // Build a request with a signature over the *wrong* material.
      // ignore: avoid_redundant_argument_values
      final http = HttpClient(context: SecurityContext(withTrustedRoots: false));
      http.badCertificateCallback = (cert, host, p) => true;
      final info = initiator.toInfo();
      final bogusSig = signPayload(
        initiator.privateKeyPem,
        Uint8List.fromList(utf8.encode('not-the-tbs')),
      );
      final req = await http.postUrl(
        Uri.parse('https://127.0.0.1:$port/pair/init'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
      req.write(PairInitMessage(info: info, signature: bogusSig).encode());
      final res = await req.close();
      expect(res.statusCode, HttpStatus.forbidden);
      http.close(force: true);
    });

    test('responder rejects a fingerprint/cert mismatch with 403', () async {
      // ignore: avoid_redundant_argument_values
      final http = HttpClient(context: SecurityContext(withTrustedRoots: false));
      http.badCertificateCallback = (cert, host, p) => true;
      // Sign honestly but lie about the fingerprint in the body.
      final info = DeviceInfo(
        deviceId: initiator.deviceId,
        name: initiator.name,
        protocolVersion: dionSyncProtocolVersion,
        certPem: initiator.certPem,
        fingerprint: 'deadbeef',
      );
      final sig = signPayload(initiator.privateKeyPem, canonicalPairingTbs(info));
      final req = await http.postUrl(
        Uri.parse('https://127.0.0.1:$port/pair/init'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
      req.write(PairInitMessage(info: info, signature: sig).encode());
      final res = await req.close();
      expect(res.statusCode, HttpStatus.forbidden);
      http.close(force: true);
    });

    test('syncWith completes over mTLS against an IP-address peer', () async {
      // This is the regression guard for the hostname-verification bug: the
      // device certs carry no SAN, so connecting to an IP-address peer would
      // fail with `CERTIFICATE_VERIFY_FAILED: IP address mismatch` unless
      // _mtlsHttpClientFor pins the server identity to the paired fingerprint.
      // Pair first so each side trusts the other's cert.
      final client = LanSyncClient(initiator);
      final paired = await client.pairWith(
        DiscoveredPeerOrAddress.fromAddress(
          InternetAddress.loopbackIPv4,
          port,
        ),
        (_, _, _) async => true,
      );
      expect(paired, isNotNull);
      // syncWith uses _mtlsHttpClientFor under the hood and drives at least one
      // authenticated request (/getSyncPointData). With matching empty repos it
      // completes without further calls.
      await client.syncWith(
        pairedDevice: paired!,
        baseUrl: 'https://127.0.0.1:$port',
        syncRepo: _FakeSyncRepo(),
      );
    });

    test('syncWith rejects a server presenting a foreign cert', () async {
      // Pair against the responder, then point syncWith at a *different* server
      // (foreign identity) on a fresh port. _mtlsHttpClientFor must refuse the
      // mismatched cert rather than TOFU-accepting it.
      final client = LanSyncClient(initiator);
      final paired = await client.pairWith(
        DiscoveredPeerOrAddress.fromAddress(
          InternetAddress.loopbackIPv4,
          port,
        ),
        (_, _, _) async => true,
      );
      expect(paired, isNotNull);

      final foreign = _makeIdentity('foreign');
      final foreignStore = PairingStore(storage: _MemoryStore());
      await foreignStore.load();
      final foreignServer = LanSyncServer(
        identity: foreign,
        pairingStore: foreignStore,
        onPairingRequest: (_, _, _) async => true,
        syncRepo: _FakeSyncRepo(),
      );
      final foreignPort =
          await foreignServer.start(address: InternetAddress.loopbackIPv4);
      try {
        expect(
          () => client.syncWith(
            pairedDevice: paired!,
            baseUrl: 'https://127.0.0.1:$foreignPort',
            syncRepo: _FakeSyncRepo(),
          ),
          // The mismatched cert is refused; depending on platform/timing this
          // surfaces as a HandshakeException, HttpException, or SocketException
          // — all subclasses of IOException.
          throwsA(isA<IOException>()),
        );
      } finally {
        await foreignServer.stop();
      }
    });
  });
}
