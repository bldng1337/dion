import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/service/lansync/discovery.dart';
import 'package:dionysos/service/lansync/lansync_service.dart';
import 'package:dionysos/service/lansync/pairing_store.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/loadable.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';

class DevicesSettings extends StatefulWidget {
  const DevicesSettings({super.key});

  @override
  State<DevicesSettings> createState() => _DevicesSettingsState();
}

class _DevicesSettingsState extends State<DevicesSettings> {
  late final LanSyncService _service;
  // Per-device in-flight operations, keyed by deviceId, to show spinners and
  // prevent duplicate concurrent actions.
  final Map<String, bool> _busy = {};

  @override
  void initState() {
    super.initState();
    _service = locate<LanSyncService>();
    unawaited(_service.startScanning());
  }

  @override
  void dispose() {
    unawaited(_service.stopScanning());
    super.dispose();
  }

  Future<void> _pair(DiscoveredPeer peer) async {
    if (_busy[peer.deviceId] == true) return;
    setState(() => _busy[peer.deviceId] = true);
    try {
      final ok = await _service.pairWith(peer);
      if (mounted) {
        _showSnack(
          ok ? 'Paired with ${peer.name}' : 'Pairing declined or failed',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Pairing failed: $e');
    } finally {
      if (mounted) setState(() => _busy[peer.deviceId] = false);
    }
  }

  Future<void> _sync(String deviceId, String name) async {
    if (_busy[deviceId] == true) return;
    setState(() => _busy[deviceId] = true);
    try {
      await _service.syncNow(deviceId);
      if (mounted) _showSnack('Synced with $name');
    } catch (e) {
      if (mounted) _showSnack('Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy[deviceId] = false);
    }
  }

  Future<void> _unpair(PairedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: Text('Remove "${device.name}" from paired devices?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.unpair(device.deviceId);
    if (mounted) _showSnack('Unpaired ${device.name}');
  }

  void _showSnack(String message) {
    final ctx = context;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Devices'),
      child: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: _service.pairingStore,
            builder: (context, _) {
              return ListenableBuilder(
                listenable: _service.discovery.peers,
                builder: (context, _) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _identitySection(context),
                        _discoveredSection(context),
                        _pairedSection(context),
                        const SizedBox(height: DionSpacing.xxxl),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _identitySection(BuildContext context) {
    return SettingTitle(
      title: 'This Device',
      subtitle: 'Visible to other devices on your local network',
      children: [
        _materialTile(
          DionListTile(
            leading: const Icon(Icons.smartphone, size: 40),
            title: Text(_service.identity.name, style: context.titleMedium),
            subtitle: Text(
              _service.identity.deviceId,
              style: context.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: context.theme.disabledColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _discoveredSection(BuildContext context) {
    final peers = _service.discovery.peers.value
        .where((p) => p.deviceId != _service.identity.deviceId)
        .toList();

    return SettingTitle(
      title: 'Discovered Devices',
      subtitle: peers.isEmpty ? 'No devices found on the network' : null,
      children: peers.isEmpty
          ? null
          : [
              for (final peer in peers)
                _materialTile(
                  DionListTile(
                    leading: const Icon(Icons.devices, size: 40),
                    title: Text(peer.name, style: context.titleMedium),
                    subtitle: Text(
                      '${peer.address.address} • v${peer.protocolVersion}',
                      style: context.bodySmall,
                    ),
                    trailing: _busy[peer.deviceId] == true
                        ? const DionProgressBar(size: 18)
                        : _service.pairingStore.containsFingerprint(
                            peer.fingerprint,
                          )
                        ? DionBadge(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DionSpacing.sm,
                                vertical: DionSpacing.xs,
                              ),
                              child: Text('Paired', style: context.labelSmall),
                            ),
                          )
                        : DionIconbutton(
                            icon: const Icon(Icons.link),
                            tooltip: 'Pair',
                            onPressed: () => _pair(peer),
                          ),
                  ),
                ),
            ],
    );
  }

  Widget _pairedSection(BuildContext context) {
    final devices = _service.pairingStore.devices;
    return SettingTitle(
      title: 'Paired Devices',
      subtitle: devices.isEmpty ? 'No paired devices yet' : null,
      children: devices.isEmpty
          ? null
          : [
              for (final device in devices)
                _materialTile(
                  DionListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 40,
                    ),
                    title: Text(device.name, style: context.titleMedium),
                    subtitle: Text(
                      device.lastSyncedAt == null
                          ? 'Never synced'
                          : 'Last synced ${device.lastSyncedAt}',
                      style: context.bodySmall,
                    ),
                    trailing: _busy[device.deviceId] == true
                        ? const DionProgressBar(size: 18)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Loadable(
                                loading: const DionProgressBar(size: 18),
                                builder: (context, _, setFuture) =>
                                    DionIconbutton(
                                      icon: const Icon(Icons.sync),
                                      tooltip: 'Sync now',
                                      onPressed: () {
                                        setFuture(
                                          _sync(device.deviceId, device.name),
                                        );
                                      },
                                    ),
                              ),
                              DionIconbutton(
                                icon: const Icon(Icons.link_off),
                                tooltip: 'Unpair',
                                onPressed: () => _unpair(device),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
    );
  }

  Widget _materialTile(DionListTile tile) =>
      Material(color: Colors.transparent, child: tile);
}
