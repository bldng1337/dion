import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart'
    hide
        ContainerType,
        CrossAxisAlignment,
        EdgeInsets,
        MainAxisAlignment,
        MainAxisSize,
        TextStyle,
        WrapAlignment;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/drawer.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart' show Divider, Icons, InkWell;
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
                  onPressed: () {
                    setState(() {
                      e.searchEnabled = !e.searchEnabled;
                    });
                  },
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
