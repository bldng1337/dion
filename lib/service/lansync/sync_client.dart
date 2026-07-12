import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/service/lansync/crypto_util.dart';
import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/signing.dart';
import 'package:metis/adapter/sync/repo.dart';

/// Callback used to ask the local user (acting as A, the initiator) to
/// confirm a pairing after B's info is known. Returns `true` if accepted.
typedef InitiatorPrompt =
    Future<bool> Function(
      DeviceInfo peerInfo,
      String peerFingerprint,
      String sasCode,
    );

class LanSyncClient {
  final DeviceIdentity _identity;

  LanSyncClient(this._identity);

  Future<DeviceInfo> fetchInfo(DiscoveredPeerOrAddress peer) async {
    final client = _pairingHttpClient();
    try {
      final req = await client.getUrl(Uri.parse('${peer.httpUrl}/info'));
      req.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode != HttpStatus.ok) {
        throw LanSyncException('info failed: ${res.statusCode} $body');
      }
      return DeviceInfo.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  /// Run the initiator side of the pairing handshake against [peer].
  ///
  /// 1. `POST /pair/init` with our info => B responds with its info + sessionId,
  ///    and (in parallel) prompts B's user.
  /// 2. [onPrompt] asks our user (A) to confirm, showing the SAS code derived
  ///    from the TLS-presented peer fingerprint.
  /// 3. `POST /pair/confirm`: both sides persist the pairing.
  ///
  /// Returns the newly paired [PairedDevice], or `null` if either side
  /// declined. Throws [LanSyncException] on protocol/transport errors.
  Future<PairedDevice?> pairWith(
    DiscoveredPeerOrAddress peer,
    InitiatorPrompt onPrompt,
  ) async {
    final client = _pairingHttpClient();
    String? peerFp;
    try {
      client.badCertificateCallback = (cert, host, port) {
        // TOFU: accept the peer's self-signed cert. Capture its fingerprint
        // so the SAS code reflects the *actual* TLS identity, not the body.
        peerFp = fingerprintOf(cert.pem);
        return true;
      };

      // 1. init wrap our info in a PairInitMessage and sign the canonical
      // encoding so the responder can verify we hold the private key for the
      // cert in the body (the pairing client does not present a TLS client
      // certificate, so identity is established via this signature).
      final info = _identity.toInfo();
      final tbs = canonicalPairingTbs(info);
      final signature = signPayload(_identity.privateKeyPem, tbs);
      final initReq = await client.postUrl(
        Uri.parse('${peer.httpUrl}/pair/init'),
      );
      initReq.headers.contentType = ContentType.json;
      initReq.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
      initReq.write(PairInitMessage(info: info, signature: signature).encode());
      final initRes = await initReq.close();
      final initBody = await utf8.decoder.bind(initRes).join();
      if (initRes.statusCode != HttpStatus.ok) {
        throw LanSyncException(
          'pair/init failed: ${initRes.statusCode} $initBody',
        );
      }
      final initMsg = PairInitMessage.decode(initBody);
      final peerInfo = initMsg.info;
      if (peerFp == null || peerFp != peerInfo.fingerprint) {
        throw LanSyncException('peer cert fingerprint mismatch');
      }
      final sessionId = initMsg.sessionId;
      if (sessionId == null) {
        throw LanSyncException('server did not return a session id');
      }

      // 2. local prompt (A)
      final sas = sasCodeString(_identity.fingerprint, peerFp!);
      final accepted = await onPrompt(peerInfo, peerFp!, sas);
      if (!accepted) {
        // Still inform B so it can discard the session.
        await _sendConfirm(client, peer.httpUrl, sessionId, false);
        return null;
      }

      // 3. confirm sign the sessionId to prove continued possession.
      final confirmSig = signPayload(
        _identity.privateKeyPem,
        Uint8List.fromList(utf8.encode(sessionId)),
      );
      final result = await _sendConfirm(
        client,
        peer.httpUrl,
        sessionId,
        true,
        signature: confirmSig,
      );
      if (!result.paired) {
        // B declined (or its session expired).
        return null;
      }

      return PairedDevice(
        deviceId: peerInfo.deviceId,
        name: peerInfo.name,
        certPem: peerInfo.certPem,
        fingerprint: peerFp!,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<PairConfirmResult> _sendConfirm(
    HttpClient client,
    String baseUrl,
    String sessionId,
    bool accept, {
    String? signature,
  }) async {
    final req = await client.postUrl(Uri.parse('$baseUrl/pair/confirm'));
    req.headers.contentType = ContentType.json;
    req.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
    req.write(
      PairConfirmMessage(
        sessionId: sessionId,
        accept: accept,
        signature: signature,
      ).encode(),
    );
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    if (res.statusCode != HttpStatus.ok) {
      throw LanSyncException('pair/confirm failed: ${res.statusCode} $body');
    }
    return PairConfirmResult.decode(body);
  }

  /// Build an mTLS [HttpClient] that presents our own client cert and pins the
  /// server identity to [pairedDevice]'s recorded fingerprint. Used for sync
  /// (protected routes).
  ///
  /// The peer's cert is added to the trust store, but that alone is not
  /// sufficient: BoringSSL still performs hostname/SAN verification, and our
  /// self-signed device certs carry no SAN, so a connection to an IP-address
  /// peer fails with `CERTIFICATE_VERIFY_FAILED: IP address mismatch`. The
  /// `badCertificateCallback` therefore accepts the cert **only** when its
  /// fingerprint equals the paired device's — binding the connection to the
  /// exact peer we paired with, rather than to hostname matching.
  HttpClient _mtlsHttpClientFor(PairedDevice pairedDevice) {
    final context = _identity.buildContext(
      trustedCertPems: [pairedDevice.certPem],
    );
    final client = HttpClient(context: context);
    client.badCertificateCallback = (cert, host, port) {
      return fingerprintOf(cert.pem) == pairedDevice.fingerprint;
    };
    return client;
  }

  /// Build an [HttpClient] for the pairing handshake. It does **not** present
  /// a client certificate: the server requests one (it must, so that mTLS sync
  /// works after pairing), but during pairing our cert is not yet in the peer's
  /// trust store, and presenting an untrusted client cert causes BoringSSL to
  /// abort the TLS handshake (`Connection closed before full header was
  /// received`). Identity is instead proven via the request-body signature
  /// (see [signing.dart]).
  ///
  /// The caller sets `badCertificateCallback` to TOFU-accept the peer's
  /// self-signed server cert and capture its fingerprint.
  HttpClient _pairingHttpClient() {
    // withTrustedRoots: false so the system root store is never consulted —
    // only TOFU-accepted peer certs (via badCertificateCallback) are trusted.
    // ignore: avoid_redundant_argument_values
    final context = SecurityContext(withTrustedRoots: false);
    return HttpClient(context: context);
  }

  Future<void> syncWith({
    required PairedDevice pairedDevice,
    required String baseUrl,
    required SyncRepo syncRepo,
    void Function(int progress, int total)? onProgress,
  }) async {
    final client = _mtlsHttpClientFor(pairedDevice);
    final remote = SyncHttpClient(url: baseUrl, client: client);
    try {
      await syncRepo.sync(remote, onProgress: onProgress);
    } finally {
      remote.dispose();
    }
  }
}

class DiscoveredPeerOrAddress {
  final String httpUrl;

  const DiscoveredPeerOrAddress._(this.httpUrl);

  factory DiscoveredPeerOrAddress.fromPeer(DiscoveredPeer peer) =>
      DiscoveredPeerOrAddress._(peer.httpUrl);

  factory DiscoveredPeerOrAddress.fromAddress(
    InternetAddress address,
    int port,
  ) => DiscoveredPeerOrAddress._('https://${address.address}:$port');
}

class LanSyncException implements Exception {
  final String message;
  LanSyncException(this.message);
  @override
  String toString() => 'LanSyncException: $message';
}
