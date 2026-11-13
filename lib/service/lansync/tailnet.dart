import 'dart:async';
import 'dart:io';

import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/identity.dart';
import 'package:dionysos/service/lansync/live_sync.dart';
import 'package:dionysos/service/lansync/protocol.dart';
import 'package:dionysos/service/lansync/sync_client.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tailscale/tailscale.dart';

enum TailnetPhase {
  off,
  connecting,
  needsLogin,
  needsApproval,
  running,
  failed,
}

@immutable
class TailnetState {
  final TailnetPhase phase;

  /// Login link while [phase] is [TailnetPhase.needsLogin].
  final Uri? authUrl;

  /// This node's tailnet IPv4 while [phase] is [TailnetPhase.running].
  final String? address;
  final String? error;

  const TailnetState(this.phase, {this.authUrl, this.address, this.error});

  static const off = TailnetState(TailnetPhase.off);
}

const _upTimeout = Duration(minutes: 1);
const _dialTimeout = Duration(seconds: 10);
const _reprobeInterval = Duration(minutes: 1);

class TailnetTransport {
  final DeviceIdentity _identity;
  final LanSyncClient _client;

  /// Port of the local sync server, or null while it is not running.
  final int? Function() _localPort;

  final ValueNotifier<TailnetState> state = ValueNotifier(TailnetState.off);

  /// Dion devices reachable over the tailnet.
  final ValueNotifier<List<DiscoveredPeer>> peers =
      ValueNotifier<List<DiscoveredPeer>>(const []);

  TailnetTransport({
    required this._identity,
    required this._client,
    required this._localPort,
  });

  static const _appId = 'com.bldng.dion';
  static Future<void>? _initialized;

  Tailscale get _ts => Tailscale.instance;

  final SyncLock _lock = SyncLock();
  bool _wanted = false;
  // Bumped on teardown so probes that outlive the node don't publish peers.
  int _generation = 0;
  bool _subscribed = false;

  TailscaleListener? _listener;
  StreamSubscription<List<TailscaleNode>>? _nodesSub;
  Timer? _reprobe;
  String? _selfNodeId;
  List<TailscaleNode> _lastNodes = const [];
  final Map<String, DiscoveredPeer> _known = {};
  final Set<String> _probing = {};
  final Map<String, Future<_Forwarder>> _forwarders = {};

  bool get isActive => state.value.phase != TailnetPhase.off;

  Future<void> start({String? authKey, Uri? controlUrl}) => _lock.run(() async {
    _wanted = true;
    final phase = state.value.phase;
    final settled = phase != TailnetPhase.off && phase != TailnetPhase.failed;
    if (settled && authKey == null) return;
    state.value = const TailnetState(TailnetPhase.connecting);
    try {
      await _ensureInitialized();
      _subscribe();
      // An auth key is ignored by a runtime that is already up, and a failed
      // one has to be replaced anyway.
      if (phase != TailnetPhase.off) {
        await _teardown();
        await _down();
      }
      final status = await _ts.up(
        hostname: _hostname(),
        authKey: authKey,
        controlUrl: controlUrl,
        timeout: _upTimeout,
      );
      await _apply(status);
    } catch (e, st) {
      logger.w('Tailnet sync: failed to start', error: e, stackTrace: st);
      await _teardown();
      state.value = TailnetState(TailnetPhase.failed, error: '$e');
    }
  });

  Future<void> stop() => _lock.run(() async {
    _wanted = false;
    if (state.value.phase == TailnetPhase.off) return;
    await _teardown();
    await _down();
    state.value = TailnetState.off;
  });

  Future<void> logout() => _lock.run(() async {
    _wanted = false;
    await _teardown();
    try {
      await _ts.logout();
    } catch (e) {
      logger.w('Tailnet sync: logout failed', error: e);
    }
    await _down();
    state.value = TailnetState.off;
  });

  static Future<void> _ensureInitialized() {
    return _initialized ??= () async {
      try {
        final support = await getApplicationSupportDirectory();
        final dir = await Directory(p.join(support.path, 'tailnet'))
            .create(recursive: true);
        Tailscale.init(
          stateDir: dir.path,
          appId: _appId,
          noLogsNoSupport: true,
        );
      } catch (_) {
        _initialized = null;
        rethrow;
      }
    }();
  }

  void _subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    // Both streams live as long as the process-wide Tailscale singleton.
    _ts.onStateChange.listen((_) {
      if (!_wanted) return;
      unawaited(_lock.run(_refresh));
    });
    _ts.onError.listen((error) {
      logger.w('Tailnet sync: runtime error', error: error);
    });
  }

  Future<void> _refresh() async {
    if (!_wanted || state.value.phase == TailnetPhase.failed) return;
    try {
      await _apply(await _ts.status());
    } catch (e) {
      logger.w('Tailnet sync: status refresh failed', error: e);
    }
  }

  Future<void> _apply(TailscaleStatus status) async {
    switch (status.state) {
      case NodeState.running:
        _selfNodeId = status.stableNodeId;
        await _bind();
        _nodesSub ??= _ts.onNodeChanges.listen(
          _onNodes,
          onError: (Object e) {
            logger.w('Tailnet sync: node inventory failed', error: e);
          },
        );
        _reprobe ??= Timer.periodic(_reprobeInterval, (_) {
          _onNodes(_lastNodes);
        });
        state.value = TailnetState(TailnetPhase.running, address: status.ipv4);
      case NodeState.needsLogin:
        await _teardown();
        state.value = TailnetState(
          TailnetPhase.needsLogin,
          authUrl: status.authUrl,
        );
      case NodeState.needsMachineAuth:
        await _teardown();
        state.value = const TailnetState(TailnetPhase.needsApproval);
      case NodeState.stopped:
        await _teardown();
        state.value = const TailnetState(
          TailnetPhase.failed,
          error: 'Disconnected from the tailnet',
        );
      case NodeState.noState || NodeState.starting || NodeState.unknown:
        state.value = const TailnetState(TailnetPhase.connecting);
    }
  }

  Future<void> _down() async {
    try {
      await _ts.down();
    } catch (e) {
      logger.w('Tailnet sync: failed to stop node', error: e);
    }
  }

  Future<void> _bind() async {
    if (_listener != null) return;
    final listener = await _ts.tcp.bind(port: dionSyncTailnetPort);
    _listener = listener;
    listener.connections.listen(
      (connection) => unawaited(_onInbound(connection)),
      onError: (Object e) {
        logger.w('Tailnet sync: accept failed', error: e);
      },
    );
    logger.i('Tailnet sync: listening on tailnet port $dionSyncTailnetPort');
  }

  Future<void> _onInbound(TailscaleConnection remote) async {
    final port = _localPort();
    if (port == null) {
      await remote.abort();
      return;
    }
    final Socket local;
    try {
      local = await Socket.connect(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      logger.w('Tailnet sync: local server unreachable', error: e);
      await remote.abort();
      return;
    }
    await _bridge(remote, local);
  }

  Future<void> _teardown() async {
    _generation++;
    _reprobe?.cancel();
    _reprobe = null;
    await _nodesSub?.cancel();
    _nodesSub = null;
    final listener = _listener;
    _listener = null;
    if (listener != null) {
      try {
        await listener.close();
      } catch (e) {
        logger.w('Tailnet sync: failed to close listener', error: e);
      }
    }
    final forwarders = _forwarders.values.toList();
    _forwarders.clear();
    for (final forwarder in forwarders) {
      try {
        await (await forwarder).close();
      } catch (_) {
        // A forwarder that never opened has nothing to close.
      }
    }
    _lastNodes = const [];
    _known.clear();
    _probing.clear();
    peers.value = const [];
  }

  void _onNodes(List<TailscaleNode> nodes) {
    _lastNodes = nodes;
    final candidates = <String, TailscaleNode>{
      for (final node in nodes)
        if (node.online &&
            node.stableNodeId != _selfNodeId &&
            node.hostName.startsWith(dionTailnetHostPrefix) &&
            node.ipv4 != null)
          node.stableNodeId: node,
    };
    final before = _known.length;
    _known.removeWhere(
      (id, peer) => candidates[id]?.ipv4 != peer.address.address,
    );
    if (_known.length != before) _publish();
    for (final node in candidates.values) {
      if (_known.containsKey(node.stableNodeId)) continue;
      if (_probing.contains(node.stableNodeId)) continue;
      unawaited(_probe(node));
    }
  }

  Future<void> _probe(TailscaleNode node) async {
    final generation = _generation;
    final ip = node.ipv4!;
    _probing.add(node.stableNodeId);
    try {
      final url = await _forwarderUrl(ip, dionSyncTailnetPort);
      final info = await _client.fetchInfo(
        DiscoveredPeerOrAddress.fromUrl(url),
      );
      if (generation != _generation) return;
      if (info.deviceId == _identity.deviceId) return;
      final stillThere = _lastNodes.any(
        (n) => n.stableNodeId == node.stableNodeId && n.online && n.ipv4 == ip,
      );
      if (!stillThere) return;
      _known[node.stableNodeId] = DiscoveredPeer(
        deviceId: info.deviceId,
        name: info.name,
        protocolVersion: info.protocolVersion,
        fingerprint: info.fingerprint,
        address: InternetAddress(ip),
        port: dionSyncTailnetPort,
        transport: PeerTransport.tailnet,
        httpUrl: url,
      );
      _publish();
    } catch (e) {
      logger.d('Tailnet sync: ${node.hostName} ($ip) is not reachable: $e');
    } finally {
      if (generation == _generation) _probing.remove(node.stableNodeId);
    }
  }

  void _publish() {
    peers.value = _known.values.toList(growable: false);
  }

  Future<String> _forwarderUrl(String host, int port) async {
    final key = '$host:$port';
    final forwarder = _forwarders[key] ??= _Forwarder.open(_ts.tcp, host, port);
    try {
      return (await forwarder).url;
    } catch (_) {
      if (identical(_forwarders[key], forwarder)) _forwarders.remove(key);
      rethrow;
    }
  }

  String _hostname() {
    final label = _identity.name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = label.isEmpty ? _identity.deviceId.substring(0, 8) : label;
    final name = '$dionTailnetHostPrefix$base';
    if (name.length <= 63) return name;
    return name.substring(0, 63).replaceAll(RegExp(r'-+$'), '');
  }
}

class _Forwarder {
  final ServerSocket _server;
  final String url;

  _Forwarder._(this._server)
    : url = lanSyncHttpUrl(InternetAddress.loopbackIPv4, _server.port);

  static Future<_Forwarder> open(Tcp tcp, String host, int port) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((local) async {
      final TailscaleConnection remote;
      try {
        remote = await tcp.dial(host, port, timeout: _dialTimeout);
      } catch (e) {
        logger.d('Tailnet sync: dial $host:$port failed: $e');
        local.destroy();
        return;
      }
      await _bridge(remote, local);
    });
    return _Forwarder._(server);
  }

  Future<void> close() => _server.close();
}

Future<void> _bridge(TailscaleConnection remote, Socket local) async {
  try {
    await Future.wait([
      local.addStream(remote.input).then((_) => local.close()),
      remote.output.writeAll(local, close: true),
    ], eagerError: true);
    await remote.close();
  } catch (_) {
    // One side dropping mid-stream just ends the tunnel; TLS on top reports
    // the failure to whoever was using it.
    await remote.abort().catchError((Object _) {});
  } finally {
    local.destroy();
  }
}
