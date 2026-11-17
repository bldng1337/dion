import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/search_profile.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart'
    hide
        ButtonType,
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/context_menu.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart'
    show Colors, Divider, Icons, InkWell, showDialog;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

/// A page that hosts an extension-driven entry feed which can be rebuilt
/// from the current extension set (browse, search, migrate).
abstract class BrowseInterface {
  List<Extension> get extensions;
  set extensions(List<Extension> value);
  Future<void> refresh();
}

/// Live feed pages, so the settings popup can re-run all of them when the
/// search sources change — no matter which page opened the popup.
final Set<BrowseInterface> _activeFeeds = {};

void registerBrowseFeed(BrowseInterface feed) => _activeFeeds.add(feed);

void unregisterBrowseFeed(BrowseInterface feed) => _activeFeeds.remove(feed);

void showSettingPopup(BuildContext context) {
  showDionPanel(context: context, builder: (context) => const SettingsPopup());
}

class SettingsPopup extends StatefulWidget {
  const SettingsPopup({super.key});

  @override
  State<SettingsPopup> createState() => _SettingsPopupState();
}

class _SettingsPopupState extends State<SettingsPopup>
    with StateDisposeScopeMixin {
  late List<Extension> allExtensions;
  final Set<String> expanded = {};

  final _profiles = settings.extension.searchProfiles;
  final _activeProfileId = settings.extension.activeSearchProfile;

  SearchProfile? get activeProfile =>
      _profiles.value.where((p) => p.id == _activeProfileId.value).firstOrNull;

  void selectProfile(SearchProfile? profile) {
    setState(() {
      _activeProfileId.value = profile?.id ?? '';
      // Switching to no profile keeps the current selection as is.
      if (profile == null) return;
      for (final e in allExtensions) {
        e.searchEnabled = profile.enabled.contains(e.id);
      }
    });
  }

  void _replaceProfile(SearchProfile profile) {
    _profiles.value = [
      for (final p in _profiles.value)
        if (p.id == profile.id) profile else p,
    ];
  }

  void toggleExtension(Extension e) {
    setState(() {
      e.searchEnabled = !e.searchEnabled;
      final profile = activeProfile;
      if (profile == null) return;
      final enabled = {...profile.enabled};
      if (e.searchEnabled) {
        enabled.add(e.id);
      } else {
        enabled.remove(e.id);
      }
      _replaceProfile(profile.copyWith(enabled: enabled));
    });
  }

  Future<void> addProfile() async {
    final name = await _showProfileNameDialog(context, title: 'New Profile');
    if (name == null || !mounted) return;
    final profile = SearchProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      enabled: {
        for (final e in allExtensions)
          if (e.searchEnabled) e.id,
      },
    );
    setState(() {
      _profiles.value = [..._profiles.value, profile];
      _activeProfileId.value = profile.id;
    });
  }

  Future<void> renameProfile(SearchProfile profile) async {
    final name = await _showProfileNameDialog(
      context,
      title: 'Rename Profile',
      initial: profile.name,
    );
    if (name == null || !mounted) return;
    setState(() => _replaceProfile(profile.copyWith(name: name)));
  }

  Future<void> deleteProfile(SearchProfile profile) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Profile',
      message: 'Delete the profile "${profile.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _profiles.value = [
        for (final p in _profiles.value)
          if (p.id != profile.id) p,
      ];
      if (_activeProfileId.value == profile.id) _activeProfileId.value = '';
    });
  }

  @override
  void initState() {
    // Get all enabled entry provider extensions (not just those with searchEnabled)
    allExtensions = locate<ExtensionService>()
        .getExtensions(
          extfilter: (e) =>
              e.isenabled &&
              (e.getExtensionTypeOrNull<ExtensionType_EntryProvider>() !=
                      null ||
                  e.data.extensionType.isEmpty),
        )
        .toList(growable: false);

    scope.addDispose(() async {
      await Future.forEach(allExtensions, (e) => e.save());
      final enabled = allExtensions
          .where((e) => e.searchEnabled)
          .toList(growable: false);
      // Copy: feeds can unregister while we await their refresh.
      for (final feed in _activeFeeds.toList()) {
        feed.extensions = enabled;
        await feed.refresh();
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
      child: Padding(
        padding: const EdgeInsets.all(DionSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Settings',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ).paddingOnly(bottom: DionSpacing.sm),
            const Divider(height: 1).paddingOnly(bottom: DionSpacing.sm),
            buildProfiles(context).paddingOnly(bottom: DionSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in allExtensions) showExtension(context, e),
                ].notNullWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfiles(BuildContext context) {
    final active = activeProfile;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _ProfilePill(
          label: 'None',
          color: context.textTertiary,
          selected: active == null,
          onTap: () => selectProfile(null),
        ),
        for (final profile in _profiles.value)
          ContextMenu(
            contextItems: [
              ContextMenuItem(
                label: 'Rename',
                icon: Icons.edit,
                onTap: () async => unawaited(renameProfile(profile)),
              ),
              ContextMenuItem(
                label: 'Delete',
                icon: Icons.delete,
                isDestructive: true,
                onTap: () async => unawaited(deleteProfile(profile)),
              ),
            ],
            child: _ProfilePill(
              label: profile.name,
              color: getColor(
                profile.name.toUpperCase(),
                saturation: 35,
                brightness: 55,
              ),
              selected: active?.id == profile.id,
              onTap: () => selectProfile(profile),
            ),
          ),
        _ProfilePill(
          label: 'New Profile',
          icon: Icons.add,
          color: context.textTertiary,
          selected: false,
          onTap: addProfile,
        ),
      ],
    );
  }

  Widget? showExtension(BuildContext context, Extension e) {
    if (e.loading || !e.isenabled) {
      return null;
    }
    final hasSearchSettings =
        e.settings[SettingKind.search]?.isNotEmpty ?? false;
    final isExpanded = expanded.contains(e.id);
    return Column(
      children: [
        InkWell(
          onTap: hasSearchSettings
              ? () => setState(() {
                  if (isExpanded) {
                    expanded.remove(e.id);
                  } else {
                    expanded.add(e.id);
                  }
                })
              : null,
          borderRadius: DionRadius.small,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DionSpacing.xs,
              vertical: DionSpacing.xs,
            ),
            child: Row(
              children: [
                DionImage(imageUrl: e.data.icon, width: 24, height: 24),
                Text(
                  e.data.name,
                  style: const TextStyle(fontSize: 16),
                ).paddingAll(10),
                const Spacer(),
                for (final MediaType mediatype in e.data.mediaType)
                  Icon(mediatype.icon),
                DionIconbutton(
                  tooltip: e.searchEnabled
                      ? 'Exclude from Search'
                      : 'Include in Search',
                  icon: Icon(
                    e.searchEnabled
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  onPressed: () => toggleExtension(e),
                ),
                if (hasSearchSettings)
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: DionDuration.fast,
                    child: const Icon(Icons.keyboard_arrow_down),
                  ).paddingOnly(left: DionSpacing.xs),
              ],
            ),
          ),
        ),
        if (isExpanded && e.searchEnabled && hasSearchSettings)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final setting in e.settings[SettingKind.search]!)
                  DionRuntimeSettingView(setting: setting),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ProfilePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Colors.white.withValues(alpha: selected ? 0.95 : 0.8);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DionRadius.sm),
      child: Clickable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DionDuration.fast,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.85 : 0.4),
            borderRadius: BorderRadius.circular(DionRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 14,
                  color: foreground,
                ).paddingOnly(right: DionSpacing.xs),
              Text(
                label,
                style: context.labelSmall?.copyWith(
                  color: foreground,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showProfileNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ProfileNameDialog(title: title, initial: initial),
  );
}

class _ProfileNameDialog extends StatefulWidget {
  final String title;
  final String initial;
  const _ProfileNameDialog({required this.title, required this.initial});

  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog>
    with StateDisposeScopeMixin {
  late final TextEditingController _name;

  @override
  void initState() {
    _name = TextEditingController(text: widget.initial)..disposedBy(scope);
    super.initState();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _name,
      builder: (context, _) => DionAlertDialog(
        title: Text(widget.title),
        content: DionTextbox(
          controller: _name,
          autofocus: true,
          maxLines: 1,
          hintText: 'Profile name',
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          DionTextbutton(
            type: ButtonType.ghost,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          DionTextbutton(
            onPressed: _name.text.trim().isEmpty ? null : _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
