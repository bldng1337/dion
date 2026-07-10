import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/utils/build_info.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/update.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/setting_title.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kRepoUrl = 'https://github.com/bldng1337/dion';

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  String? _versionString;
  String? _commit;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _resolveBuildInfo();
  }

  Future<void> _resolveBuildInfo() async {
    final version = await getVersion();
    if (!mounted) return;
    setState(() {
      _versionString = version.toString();
      // Prefer the build-injected commit (nightly builds); it is absent on
      // release builds, where it stays null and the row is hidden.
      _commit = BuildInfo.commit.isNotEmpty ? BuildInfo.commit : null;
    });
  }

  String get _channelLabel {
    if (BuildInfo.isNightly) return 'Nightly';
    return switch (settings.update.channel.value) {
      UpdateChannel.stable => 'Stable',
      UpdateChannel.beta => 'Beta',
      UpdateChannel.nightly => 'Nightly',
    };
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    final result = await checkVersion(force: true);
    if (!mounted) return;
    setState(() => _checking = false);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    final message = switch (result) {
      CheckResult.upToDate => 'You are on the latest version.',
      CheckResult.updateAvailable => 'An update is available.',
      CheckResult.error =>
        'Could not check for updates. Check your connection and try again.',
      CheckResult.skipped => 'Update check was skipped.',
    };
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('About'),
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: [
          _AppHeader(
            version: _versionString,
            channel: _channelLabel,
            isNightly: BuildInfo.isNightly,
          ),

          SettingTitle(
            title: 'Updates',
            subtitle: 'Check for newer versions',
            children: [
              _ActionRow(
                icon: Icons.refresh_outlined,
                title: 'Check for updates',
                description: _versionString == null
                    ? null
                    : 'Currently on $_versionString',
                trailing: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: context.textTertiary,
                      ),
                onTap: _checking ? null : _checkForUpdates,
              ),
            ],
          ),

          const SettingTitle(
            title: 'Links',
            subtitle: 'Project resources',
            children: [
              _LinkRow(
                icon: Icons.code_outlined,
                title: 'Source code',
                subtitle: 'github.com/bldng1337/dion',
                url: _kRepoUrl,
              ),
              _LinkRow(
                icon: Icons.bug_report_outlined,
                title: 'Report an issue',
                subtitle: 'Open a GitHub issue',
                url: '$_kRepoUrl/issues',
              ),
              _LinkRow(
                icon: Icons.new_releases_outlined,
                title: 'Releases',
                subtitle: 'All published versions',
                url: '$_kRepoUrl/releases',
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DionSpacing.lg,
              vertical: DionSpacing.lg,
            ),
            child: Text(
              'An extensible media reader for novels, comics, video and audio.',
              textAlign: TextAlign.center,
              style: DionTypography.bodySmall(context.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app icon, name, and a one-line version/channel summary.
class _AppHeader extends StatelessWidget {
  final String? version;
  final String channel;
  final bool isNightly;

  const _AppHeader({
    required this.version,
    required this.channel,
    required this.isNightly,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DionSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DionRadius.xl),
              image: const DecorationImage(
                image: AssetImage('assets/icon/icon.png'),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: DionSpacing.md),
          Text('dion', style: DionTypography.displayLarge(context.textPrimary)),
          const SizedBox(height: DionSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                version ?? '…',
                style: DionTypography.bodyMedium(context.textSecondary),
              ),
              const SizedBox(width: DionSpacing.sm),
              _ChannelBadge(label: channel, isNightly: isNightly),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small pill indicating the build channel. Nightly uses a warning tint to
/// signal its pre-release nature.
class _ChannelBadge extends StatelessWidget {
  final String label;
  final bool isNightly;

  const _ChannelBadge({required this.label, required this.isNightly});

  @override
  Widget build(BuildContext context) {
    final color = isNightly ? DionColors.warning : DionColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DionRadius.small,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label, style: DionTypography.labelSmall(color)),
    );
  }
}

/// A label/value row grouped inside a [SettingTitle] section.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DionSpacing.lg,
        vertical: DionSpacing.md,
      ),
      child: Row(
        children: [
          Text(label, style: DionTypography.bodyMedium(context.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: DionTypography.titleSmall(context.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable row with an icon, title, optional description, and trailing
/// widget. Used for the "Check for updates" action.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.textSecondary),
              const SizedBox(width: DionSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DionTypography.titleSmall(context.textPrimary),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: DionTypography.bodySmall(context.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: DionSpacing.md),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// A row that opens an external URL when tapped.
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.textSecondary),
              const SizedBox(width: DionSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: DionTypography.titleSmall(context.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DionTypography.bodySmall(context.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DionSpacing.md),
              Icon(Icons.open_in_new, size: 16, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
