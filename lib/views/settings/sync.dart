import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/lansync/lansync_service.dart';
import 'package:dionysos/service/lansync/tailnet.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/dialog/tailscale_auth_key.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/listtile.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_directory.dart';
import 'package:dionysos/widgets/settings/setting_dropdown.dart';
import 'package:dionysos/widgets/settings/setting_textbox.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:dionysos/widgets/settings/setting_toggle.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SyncSettings extends StatelessWidget {
  const SyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Synchronisation'),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          settings.sync.mode,
          settings.sync.lan.tailscale.enabled,
        ]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
          children: [
            SettingTitle(
              title: 'Synchronisation',
              subtitle: 'How this device keeps its library in sync',
              children: [
                SettingDropdown(
                  title: 'Sync Mode',
                  description:
                      'Merge with a database file in a folder, or sync '
                      'directly with paired devices on your network',
                  setting: settings.sync.mode,
                ),
              ],
            ),
            if (settings.sync.mode.value == SyncMode.file)
              SettingTitle(
                title: 'Local Database File',
                subtitle: 'Merged into your library each time the app starts',
                children: [
                  SettingDirectory(
                    title: 'Sync Directory',
                    description: 'Folder holding the database to merge with',
                    setting: settings.sync.path,
                  ),
                ],
              ),
            if (settings.sync.mode.value == SyncMode.lan)
              SettingTitle(
                title: 'LAN Sync',
                subtitle:
                    'Pair with other devices on your Wi-Fi to sync directly',
                children: [
                  SettingTextbox(
                    title: 'Device Name',
                    description: 'Shown to other devices when pairing',
                    setting: settings.sync.lan.deviceName,
                  ),
                  SettingToggle(
                    title: 'Discoverable',
                    description: 'Let other devices find this device',
                    setting: settings.sync.lan.discoverable,
                  ),
                  SettingToggle(
                    title: 'Auto Sync',
                    description:
                        'Sync with paired devices automatically whenever both '
                        'are online',
                    setting: settings.sync.lan.autoSync,
                  ),
                  SettingToggle(
                    title: 'Live Sync',
                    description:
                        'Push changes to online devices as they happen instead '
                        'of waiting for the next sync',
                    setting: settings.sync.lan.livesync,
                  ),
                ],
              ),
            if (settings.sync.mode.value == SyncMode.lan)
              SettingTitle(
                title: 'Tailscale',
                subtitle:
                    'Reach paired devices from anywhere through your tailnet',
                children: [
                  SettingToggle(
                    title: 'Sync over Tailscale',
                    description:
                        'Join your tailnet as its own device so other devices '
                        'running dion there can pair and sync, even away from '
                        'home. No Tailscale app needed',
                    setting: settings.sync.lan.tailscale.enabled,
                  ),
                  if (settings.sync.lan.tailscale.enabled.value) ...[
                    if (has<LanSyncService>()) const _TailnetStatusTile(),
                    SettingTextbox(
                      title: 'Control Server',
                      description:
                          'Leave empty for Tailscale; set a URL to use a '
                          'self-hosted server such as Headscale',
                      setting: settings.sync.lan.tailscale.controlUrl,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TailnetStatusTile extends StatelessWidget {
  const _TailnetStatusTile();

  Future<void> _connectWithKey(
    BuildContext context,
    LanSyncService service,
  ) async {
    final key = await showDialog<String>(
      context: context,
      builder: (context) => const TailscaleAuthKeyDialog(),
    );
    if (key == null) return;
    await service.connectTailnet(authKey: key);
  }

  @override
  Widget build(BuildContext context) {
    final service = locate<LanSyncService>();
    return ListenableBuilder(
      listenable: Listenable.merge([service, service.tailnet.state]),
      builder: (context, _) {
        final state = service.tailnet.state.value;
        final (icon, title, detail) = switch (state.phase) {
          TailnetPhase.off when !service.isRunning => (
            Icons.cloud_off,
            'Not connected',
            'Starts together with LAN sync',
          ),
          TailnetPhase.off => (Icons.cloud_off, 'Not connected', null),
          TailnetPhase.connecting => (Icons.cloud_sync, 'Connecting…', null),
          TailnetPhase.needsLogin => (
            Icons.login,
            'Login required',
            'Log in to add this device to your tailnet',
          ),
          TailnetPhase.needsApproval => (
            Icons.hourglass_top,
            'Waiting for approval',
            'An admin of the tailnet has to approve this device',
          ),
          TailnetPhase.running => (
            Icons.cloud_done,
            'Connected',
            state.address,
          ),
          TailnetPhase.failed => (Icons.error_outline, 'Failed', state.error),
        };
        final actions = <Widget>[
          if (state.phase == TailnetPhase.needsLogin && state.authUrl != null)
            DionTextbutton(
              onPressed: () => launchUrl(state.authUrl!),
              child: const Text('Log in'),
            ),
          if (state.phase == TailnetPhase.needsLogin)
            DionTextbutton(
              type: ButtonType.ghost,
              onPressed: () => _connectWithKey(context, service),
              child: const Text('Use auth key'),
            ),
          if (service.isRunning &&
              (state.phase == TailnetPhase.off ||
                  state.phase == TailnetPhase.failed))
            DionTextbutton(
              onPressed: service.connectTailnet,
              child: const Text('Connect'),
            ),
          if (state.phase == TailnetPhase.running ||
              state.phase == TailnetPhase.needsApproval)
            DionTextbutton(
              type: ButtonType.ghost,
              onPressed: service.tailnet.logout,
              child: const Text('Log out'),
            ),
        ];
        return Material(
          color: Colors.transparent,
          child: DionListTile(
            leading: state.phase == TailnetPhase.connecting
                ? const DionProgressBar(size: 24)
                : Icon(
                    icon,
                    color: state.phase == TailnetPhase.running
                        ? DionColors.success
                        : context.textSecondary,
                  ),
            title: Text(title, style: context.titleSmall),
            subtitle: detail == null
                ? null
                : Text(detail, style: context.bodySmall),
            trailing: actions.isEmpty
                ? null
                : Wrap(spacing: DionSpacing.sm, children: actions),
          ),
        );
      },
    );
  }
}
