import 'package:dionysos/routes.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A navigation item in the settings screen.
class SettingNav extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String path;

  const SettingNav({
    super.key,
    required this.title,
    required this.icon,
    required this.path,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(path),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DionSpacing.lg,
            vertical: DionSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DionColors.primary.withValues(alpha: 0.1),
                  borderRadius: DionRadius.small,
                ),
                child: Icon(icon, size: 18, color: DionColors.primary),
              ),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: DionTypography.bodySmall(context.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section header for settings categories.
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<SettingNav> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(
            left: DionSpacing.lg,
            right: DionSpacing.lg,
            top: DionSpacing.xl,
            bottom: DionSpacing.sm,
          ),
          child: Text(
            title.toUpperCase(),
            style: DionTypography.sectionHeader(context.textTertiary),
          ),
        ),

        // Items in a grouped container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DionSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceMuted.withValues(alpha: 0.4),
              borderRadius: DionRadius.medium,
              border: Border.all(
                color: context.borderColor.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildItems(context),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DionSpacing.md),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: context.dionDivider.withValues(alpha: 0.7),
            ),
          ),
        );
      }
    }
    return result;
  }
}

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Settings'),
      destination: homedestinations,
      child: ListView(
        padding: const EdgeInsets.only(bottom: DionSpacing.xxxl),
        children: const [
          _SettingsSection(
            title: 'Readers',
            items: [
              SettingNav(
                title: 'Paragraph Reader',
                subtitle: 'Text formatting, fonts, and reading options',
                icon: Icons.article_outlined,
                path: '/settings/paragraphreader',
              ),
              SettingNav(
                title: 'Audio Listener',
                subtitle: 'Playback controls and audio settings',
                icon: Icons.headphones_outlined,
                path: '/settings/audiolistener',
              ),
              SettingNav(
                title: 'Image List Reader',
                subtitle: 'Image display and navigation',
                icon: Icons.image_outlined,
                path: '/settings/imagelistreader',
              ),
            ],
          ),
          _SettingsSection(
            title: 'Data',
            items: [
              SettingNav(
                title: 'Synchronisation',
                subtitle: 'Cloud sync and backup options',
                icon: Icons.sync_outlined,
                path: '/settings/sync',
              ),
              SettingNav(
                title: 'Storage',
                subtitle: 'Cache and download management',
                icon: Icons.storage_outlined,
                path: '/settings/storage',
              ),
            ],
          ),
          _SettingsSection(
            title: 'Library',
            items: [
              SettingNav(
                title: 'Library Settings',
                subtitle: 'Organization and display options',
                icon: Icons.local_library_outlined,
                path: '/settings/library',
              ),
              SettingNav(
                title: 'Updates',
                subtitle: 'Update check and notification settings',
                icon: Icons.update_outlined,
                path: '/settings/update',
              ),
              SettingNav(
                title: 'Active Tasks',
                subtitle: 'Background processes and downloads',
                icon: Icons.playlist_play_outlined,
                path: '/settings/tasks',
              ),
            ],
          ),
          _SettingsSection(
            title: 'Advanced',
            items: [
              SettingNav(
                title: 'Developer Settings',
                subtitle: 'Debug options and logging',
                icon: Icons.code_outlined,
                path: '/dev',
              ),
              SettingNav(
                title: 'Extension Settings',
                subtitle: 'Manage installed extensions',
                icon: Icons.extension_outlined,
                path: '/settings/extension',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
