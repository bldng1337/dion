import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dionysos/service/lansync/crypto_util.dart';
import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
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

      // 1. init
      final initReq = await client.postUrl(
        Uri.parse('${peer.httpUrl}/pair/init'),
      );
      initReq.headers.contentType = ContentType.json;
      initReq.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
      initReq.write(_identity.toInfo().encode());
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

      // 3. confirm
      final result = await _sendConfirm(client, peer.httpUrl, sessionId, true);
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
    bool accept,
  ) async {
    final req = await client.postUrl(Uri.parse('$baseUrl/pair/confirm'));
    req.headers.contentType = ContentType.json;
    req.headers.set(protocolVersionHeader, '$dionSyncProtocolVersion');
    req.write(
      PairConfirmMessage(sessionId: sessionId, accept: accept).encode(),
    );
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    if (res.statusCode != HttpStatus.ok) {
      throw LanSyncException('pair/confirm failed: ${res.statusCode} $body');
    }
    return PairConfirmResult.decode(body);
  }

  /// Build an mTLS [HttpClient] that trusts [pairedDevice]'s cert and presents
  /// our own. Used for sync (protected routes).
  HttpClient _mtlsHttpClientFor(PairedDevice pairedDevice) {
    final context = _identity.buildContext(
      trustedCertPems: [pairedDevice.certPem],
    );
    final client = HttpClient(context: context);
    // The peer's cert is in our trust store, so no badCertificateCallback is
    // needed for a paired connection.
    return client;
  }

  /// Build an [HttpClient] that presents our own cert (client cert) but
  /// accepts any server cert via [badCertificateCallback] (TOFU). The caller
  /// sets the callback to capture/validate the peer fingerprint.
  HttpClient _pairingHttpClient() {
    final context = _identity.buildContext();
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
