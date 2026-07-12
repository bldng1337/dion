import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/service/lansync/crypto_util.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/signing.dart';
import 'package:dionysos/utils/log.dart';
import 'package:metis/adapter/sync/repo.dart';
import 'package:uuid/uuid.dart';

/// A pending pairing session created by [/pair/init] and consumed by
/// [/pair/confirm]. Sessions expire after [_kSessionTtl].
class _PairSession {
  final String sessionId;
  final DeviceInfo peerInfo;
  final String peerFingerprint;
  bool accepted;
  final DateTime expires;

  _PairSession({
    required this.sessionId,
    required this.peerInfo,
    required this.peerFingerprint,
    required this.accepted,
    required this.expires,
  });

  bool get isExpired => DateTime.now().isAfter(expires);
}

/// Callback used to ask the local user to confirm an incoming pairing request
/// (the device acting as B in the handshake). Returns `true` if accepted.
typedef PairingPrompt =
    Future<bool> Function(
      DeviceInfo peerInfo,
      String peerFingerprint,
      String sasCode,
    );

/// The TLS-secured dion sync HTTP server.
///
/// Routes:
/// - `GET  /info`            open: returns the local [DeviceInfo].
/// - `POST /pair/init`       open: begins a pairing session, prompts the local
///   user to accept, returns B's info + sessionId.
/// - `POST /pair/confirm`    open: completes a pairing session if the local
///   user previously accepted.
/// - `POST /getSyncData`, `/getSyncPointData`, `/pull`, `/push`,
///   `/querySyncData`        mTLS-protected: the caller must present a paired
///   client certificate; requests are delegated to metis's [SyncHttpServer].
class LanSyncServer {
  final DeviceIdentity _identity;
  final PairingStore _pairingStore;
  final PairingPrompt _onPairingRequest;
  final SyncRepo _syncRepo;

  /// Invoked after a pairing is added or removed on this side, so the service
  /// can rebuild the [SecurityContext] (see [restart]). Not invoked for
  /// non-structural changes such as [PairingStore.markSynced].
  Future<void> Function()? onPairingChanged;

  HttpServer? _server;
  final Map<String, _PairSession> _sessions = {};
  static const _kSessionTtl = Duration(minutes: 2);
  Timer? _sessionSweeper;

  LanSyncServer({
    required DeviceIdentity identity,
    required PairingStore pairingStore,
    required PairingPrompt onPairingRequest,
    required SyncRepo syncRepo,
    this.onPairingChanged,
  }) : _identity = identity,
       _pairingStore = pairingStore,
       _onPairingRequest = onPairingRequest,
       _syncRepo = syncRepo;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  Future<int> start({dynamic address, int port = 0}) async {
    if (_server != null) return _server!.port;
    final context = _identity.buildContext(
      trustedCertPems: _pairingStore.trustedCertPems,
    );
    _server = await HttpServer.bindSecure(
      address ?? InternetAddress.anyIPv4,
      port,
      context,
      requestClientCertificate: true,
    );
    _sessionSweeper ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sweepSessions(),
    );
    logger.i(
      'LAN sync server listening on ${_server!.address}:${_server!.port}',
    );
    _serve();
    return _server!.port;
  }

  /// Rebuild the [SecurityContext] (e.g. after a pairing change) and rebind.
  /// The port is preserved so mDNS advertisement stays valid.
  Future<void> restart() async {
    final boundPort = _server?.port;
    await stop();
    await start(port: boundPort ?? 0);
  }

  Future<void> stop() async {
    _sessionSweeper?.cancel();
    _sessionSweeper = null;
    _sessions.clear();
    final s = _server;
    _server = null;
    if (s != null) {
      try {
        await s.close(force: true);
      } catch (e) {
        logger.w('LAN sync server: error closing', error: e);
      }
    }
  }

  void _serve() {
    final server = _server;
    if (server == null) return;
    () async {
      await for (final req in server) {
        try {
          await _handle(req);
        } catch (e, st) {
          logger.e(
            'LAN sync server: unhandled error',
            error: e,
            stackTrace: st,
          );
          _respond(req, HttpStatus.internalServerError, {
            'error': 'internal error',
          });
        }
      }
    }();
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.requestedUri.path;
    final pv = req.headers.value(protocolVersionHeader);
    // /info and /pair/* are the entry points: a version mismatch there is a
    // hard error. For sync routes the metis sync() call also checks schema
    // versions, but we still gate on protocol version.
    if (path == '/info' && req.method == 'GET') {
      _respond(
        req,
        HttpStatus.ok,
        _identity.toInfo().toJson(),
        version: dionSyncProtocolVersion,
      );
      return;
    }

    if (pv != null && int.tryParse(pv) != dionSyncProtocolVersion) {
      _respond(req, HttpStatus.badRequest, {
        'error': 'protocol version mismatch',
      }, version: dionSyncProtocolVersion);
      return;
    }

    if (path == '/pair/init' && req.method == 'POST') {
      await _handlePairInit(req);
      return;
    }
    if (path == '/pair/confirm' && req.method == 'POST') {
      await _handlePairConfirm(req);
      return;
    }

    // Everything else is a sync route requiring mTLS.
    if (_isSyncRoute(path)) {
      final authorized = _authorize(req);
      if (!authorized) {
        _respond(req, HttpStatus.unauthorized, {
          'error': 'client cert required',
        }, version: dionSyncProtocolVersion);
        return;
      }
      final metisServer = SyncHttpServer(repo: _syncRepo);
      await metisServer.handle(req, path);
      return;
    }

    _respond(req, HttpStatus.notFound, {
      'error': 'not found',
    }, version: dionSyncProtocolVersion);
  }

  static const _syncRoutes = {
    '/getSyncData',
    '/getSyncPointData',
    '/pull',
    '/push',
    '/querySyncData',
  };

  bool _isSyncRoute(String path) => _syncRoutes.contains(path);

  /// Authorize an mTLS request: the peer must present a certificate whose
  /// fingerprint is in the paired set.
  bool _authorize(HttpRequest req) {
    final fp = _peerFingerprint(req);
    if (fp == null) return false;
    return _pairingStore.containsFingerprint(fp);
  }

  /// Fingerprint of the TLS-presented client certificate, computed identically
  /// to [DeviceIdentity.fingerprint] (SHA-256 of the DER bytes).
  String? _peerFingerprint(HttpRequest req) {
    final cert = req.certificate;
    if (cert == null) return null;
    return fingerprintOf(cert.pem);
  }

  Future<void> _handlePairInit(HttpRequest req) async {
    final body = await _readJson(req);
    if (body == null) {
      _respond(req, HttpStatus.badRequest, {
        'error': 'invalid body',
      }, version: dionSyncProtocolVersion);
      return;
    }
    final msg = PairInitMessage.fromJson(body);
    final peerInfo = msg.info;
    // Identity comes from the request body, not a TLS client cert (the pairing
    // client presents none). Require a valid signature over the canonical
    // encoding of the initiator's info, made with the private key matching the
    // cert in the body — this proves the sender holds that key.
    final tbs = canonicalPairingTbs(peerInfo);
    if (msg.signature == null ||
        !verifyPayload(peerInfo.certPem, tbs, msg.signature!)) {
      _respond(req, HttpStatus.forbidden, {
        'error': 'invalid signature',
      }, version: dionSyncProtocolVersion);
      return;
    }
    // The fingerprint must match the cert in the body, not a stale value.
    final peerFp = fingerprintOf(peerInfo.certPem);
    if (peerFp != peerInfo.fingerprint) {
      _respond(req, HttpStatus.forbidden, {
        'error': 'cert fingerprint mismatch',
      }, version: dionSyncProtocolVersion);
      return;
    }
    // Reject if already paired.
    if (_pairingStore.containsFingerprint(peerFp)) {
      _respond(req, HttpStatus.conflict, {
        'error': 'already paired',
      }, version: dionSyncProtocolVersion);
      return;
    }

    final sessionId = const Uuid().v4();
    final session = _PairSession(
      sessionId: sessionId,
      peerInfo: peerInfo,
      peerFingerprint: peerFp,
      accepted: false,
      expires: DateTime.now().add(_kSessionTtl),
    );
    _sessions[sessionId] = session;

    final sas = sasCodeString(_identity.fingerprint, peerFp);
    // Prompt the local user (B). This may take a while; we await it so the
    // response reflects the outcome. The initiator (A) shows its own prompt
    // only after receiving this response.
    bool accepted = false;
    try {
      accepted = await _onPairingRequest(peerInfo, peerFp, sas);
    } catch (e) {
      logger.w('LAN sync: pairing prompt failed', error: e);
    }
    session.accepted = accepted;

    // Respond with B's info + the sessionId. If B declined, we still return
    // the info so A can show the prompt, but mark acceptance in the session;
    // A's confirm will then fail.
    _respond(
      req,
      HttpStatus.ok,
      PairInitMessage(info: _identity.toInfo(), sessionId: sessionId).toJson(),
      version: dionSyncProtocolVersion,
    );
  }

  Future<void> _handlePairConfirm(HttpRequest req) async {
    final body = await _readJson(req);
    if (body == null) {
      _respond(req, HttpStatus.badRequest, {
        'error': 'invalid body',
      }, version: dionSyncProtocolVersion);
      return;
    }
    final msg = PairConfirmMessage.fromJson(body);
    final session = _sessions.remove(msg.sessionId);
    if (session == null || session.isExpired) {
      _respond(
        req,
        HttpStatus.notFound,
        const PairConfirmResult(
          paired: false,
          error: 'session not found',
        ).toJson(),
        version: dionSyncProtocolVersion,
      );
      return;
    }
    // The confirmer must prove continued possession of the private key for the
    // cert bound to this session, by signing the sessionId.
    if (msg.signature == null ||
        !verifyPayload(
          session.peerInfo.certPem,
          Uint8List.fromList(utf8.encode(msg.sessionId)),
          msg.signature!,
        )) {
      _respond(
        req,
        HttpStatus.forbidden,
        const PairConfirmResult(paired: false, error: 'cert mismatch').toJson(),
        version: dionSyncProtocolVersion,
      );
      return;
    }
    if (!session.accepted || !msg.accept) {
      _respond(
        req,
        HttpStatus.ok,
        const PairConfirmResult(paired: false, error: 'declined').toJson(),
        version: dionSyncProtocolVersion,
      );
      return;
    }

    // Both sides accepted — persist the pairing.
    await _pairingStore.add(
      PairedDevice(
        deviceId: session.peerInfo.deviceId,
        name: session.peerInfo.name,
        certPem: session.peerInfo.certPem,
        fingerprint: session.peerFingerprint,
      ),
    );
    // Await the response flush *before* restarting the server: restart() calls
    // stop() which force-closes in-flight connections, so closing here first
    // ensures the client receives the full 200 response.
    await _respond(
      req,
      HttpStatus.ok,
      const PairConfirmResult(paired: true).toJson(),
      version: dionSyncProtocolVersion,
    );
    // Rebuild the trust store so the newly paired peer's cert is accepted on
    // subsequent mTLS sync requests.
    await onPairingChanged?.call();
  }

  Future<Map<String, dynamic>?> _readJson(HttpRequest req) async {
    try {
      final content = await utf8.decoder.bind(req).join();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _respond(
    HttpRequest req,
    int status,
    Map<String, dynamic> body, {
    int? version,
  }) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json;
    if (version != null) {
      req.response.headers.set(protocolVersionHeader, '$version');
    }
    req.response.write(jsonEncode(body));
    return req.response.close();
  }

  void _sweepSessions() {
    final now = DateTime.now();
    _sessions.removeWhere((_, s) => now.isAfter(s.expires));
  }
}
