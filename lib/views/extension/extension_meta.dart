import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart' as src;
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/widgets/searchbar.dart';
import 'package:flutter/material.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// The kinds an installed [src.Extension] provides, expressed through the
/// runtime's listing-friendly [rust.ExtensionKind] enum so installed and
/// remote extensions can be filtered and displayed uniformly.
extension InstalledExtensionKinds on src.Extension {
  List<rust.ExtensionKind> get extensionKinds => [
    for (final type in data.extensionType)
      switch (type) {
        rust.ExtensionType_EntryProvider() => rust.ExtensionKind.entryProvider,
        rust.ExtensionType_SourceProcessor() =>
          rust.ExtensionKind.sourceProcessor,
        rust.ExtensionType_EntryProcessor() =>
          rust.ExtensionKind.entryProcessor,
        rust.ExtensionType_URLHandler() => rust.ExtensionKind.urlHandler,
      },
  ];
}

extension ExtensionKindPresentation on rust.ExtensionKind {
  String get label => switch (this) {
    rust.ExtensionKind.entryProvider => 'Entry Provider',
    rust.ExtensionKind.sourceProcessor => 'Source Processor',
    rust.ExtensionKind.entryProcessor => 'Entry Processor',
    rust.ExtensionKind.urlHandler => 'URL Handler',
  };

  IconData get icon => switch (this) {
    rust.ExtensionKind.entryProvider => Icons.apps,
    rust.ExtensionKind.sourceProcessor => Icons.document_scanner_outlined,
    rust.ExtensionKind.entryProcessor => Icons.tune,
    rust.ExtensionKind.urlHandler => Icons.link,
  };
}

enum NsfwFilter {
  any,
  only,
  hide;

  String get label => switch (this) {
    NsfwFilter.any => 'NSFW: All',
    NsfwFilter.only => 'NSFW only',
    NsfwFilter.hide => 'Hide NSFW',
  };

  NsfwFilter get next => switch (this) {
    NsfwFilter.any => NsfwFilter.only,
    NsfwFilter.only => NsfwFilter.hide,
    NsfwFilter.hide => NsfwFilter.any,
  };

  bool matches(bool nsfw) => switch (this) {
    NsfwFilter.any => true,
    NsfwFilter.only => nsfw,
    NsfwFilter.hide => !nsfw,
  };
}

/// Client-side search and filtering, shared between the installed and the
/// remote (catalog) extension lists so both offer the same controls.
class ExtensionFilters {
  final String query;
  final NsfwFilter nsfw;
  final Set<rust.ExtensionKind> kinds;
  final Set<rust.MediaType> mediaTypes;
  final Set<String> languages;

  const ExtensionFilters({
    this.query = '',
    this.nsfw = NsfwFilter.any,
    this.kinds = const {},
    this.mediaTypes = const {},
    this.languages = const {},
  });

  bool get isActive =>
      query.isNotEmpty ||
      nsfw != NsfwFilter.any ||
      kinds.isNotEmpty ||
      mediaTypes.isNotEmpty ||
      languages.isNotEmpty;

  ExtensionFilters copyWith({
    String? query,
    NsfwFilter? nsfw,
    Set<rust.ExtensionKind>? kinds,
    Set<rust.MediaType>? mediaTypes,
    Set<String>? languages,
  }) {
    return ExtensionFilters(
      query: query ?? this.query,
      nsfw: nsfw ?? this.nsfw,
      kinds: kinds ?? this.kinds,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      languages: languages ?? this.languages,
    );
  }

  bool matchesInstalled(src.Extension e) {
    return _matches(
      text: [e.name, ...e.data.author, ...e.data.tags],
      nsfw: e.data.nsfw,
      kinds: e.extensionKinds,
      mediaTypes: e.data.mediaType,
      languages: e.data.lang,
    );
  }

  bool matchesRemote(src.RemoteExtension e) {
    return _matches(
      text: [e.name, ...e.authors, ...e.tags],
      nsfw: e.nsfw,
      kinds: e.extensionKinds,
      mediaTypes: e.mediaType,
      languages: e.lang,
    );
  }

  bool _matches({
    required Iterable<String> text,
    required bool nsfw,
    required List<rust.ExtensionKind> kinds,
    required Set<rust.MediaType> mediaTypes,
    required List<String> languages,
  }) {
    if (!this.nsfw.matches(nsfw)) {
      return false;
    }
    // Empty selections mean "any"; otherwise one match suffices.
    if (this.kinds.isNotEmpty && !this.kinds.any(kinds.contains)) {
      return false;
    }
    if (this.mediaTypes.isNotEmpty &&
        !this.mediaTypes.any(mediaTypes.contains)) {
      return false;
    }
    if (this.languages.isNotEmpty && !this.languages.any(languages.contains)) {
      return false;
    }
    final q = query.toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return text.any((t) => t.toLowerCase().contains(q));
  }
}

/// Search bar plus the shared filter chips (nsfw, extension kind, media type,
/// language) used by both extension list tabs.
class ExtensionFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String? searchHint;
  final ExtensionFilters filters;
  final ValueChanged<ExtensionFilters> onChanged;
  final Iterable<String> languageOptions;

  const ExtensionFilterBar({
    super.key,
    required this.searchController,
    required this.filters,
    required this.onChanged,
    this.languageOptions = const {},
    this.searchHint,
  });

  void _toggleKind(rust.ExtensionKind kind) {
    final next = Set<rust.ExtensionKind>.of(filters.kinds);
    if (!next.remove(kind)) {
      next.add(kind);
    }
    onChanged(filters.copyWith(kinds: next));
  }

  void _toggleMediaType(rust.MediaType type) {
    final next = Set<rust.MediaType>.of(filters.mediaTypes);
    if (!next.remove(type)) {
      next.add(type);
    }
    onChanged(filters.copyWith(mediaTypes: next));
  }

  void _toggleLanguage(String lang) {
    final next = Set<String>.of(filters.languages);
    if (!next.remove(lang)) {
      next.add(lang);
    }
    onChanged(filters.copyWith(languages: next));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DionSearchbar(
          controller: searchController,
          hintText: searchHint ?? 'Search extensions',
          onChanged: (value) =>
              onChanged(filters.copyWith(query: value.trim())),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(top: DionSpacing.xs),
          child: Row(
            // The volatile chips (NSFW, whose label changes with its state,
            // and Clear, which appears only when filters are active) sit at
            // the end so toggling them never shifts the stable chips, and
            // showCheckmark: false keeps selections from resizing them.
            children: [
              for (final kind in rust.ExtensionKind.values)
                _chip(
                  FilterChip(
                    avatar: Tooltip(
                      message: kind.label,
                      child: Icon(kind.icon, size: 18),
                    ),
                    label: Text(kind.label),
                    showCheckmark: false,
                    selected: filters.kinds.contains(kind),
                    onSelected: (_) => _toggleKind(kind),
                  ),
                ),
              for (final type in rust.MediaType.values)
                if (type != rust.MediaType.unknown)
                  _chip(
                    FilterChip(
                      avatar: Icon(type.icon, size: 18),
                      label: Text(
                        type.name[0].toUpperCase() + type.name.substring(1),
                      ),
                      showCheckmark: false,
                      selected: filters.mediaTypes.contains(type),
                      onSelected: (_) => _toggleMediaType(type),
                    ),
                  ),
              for (final lang in languageOptions.toList()..sort())
                _chip(
                  FilterChip(
                    label: Text(lang.toUpperCase()),
                    showCheckmark: false,
                    selected: filters.languages.contains(lang),
                    onSelected: (_) => _toggleLanguage(lang),
                  ),
                ),
              _chip(
                FilterChip(
                  avatar: const Icon(Icons.no_adult_content, size: 18),
                  label: Text(filters.nsfw.label),
                  showCheckmark: false,
                  selected: filters.nsfw != NsfwFilter.any,
                  onSelected: (_) =>
                      onChanged(filters.copyWith(nsfw: filters.nsfw.next)),
                ),
              ),
              if (filters.isActive)
                _chip(
                  FilterChip(
                    avatar: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                    showCheckmark: false,
                    onSelected: (_) {
                      searchController.clear();
                      onChanged(const ExtensionFilters());
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(Widget chip) {
    return Padding(
      padding: const EdgeInsets.only(right: DionSpacing.sm),
      child: chip,
    );
  }
}

/// Compact badges describing what an extension is and deals with: extension
/// kinds, media types, an 18+ marker when nsfw, and its languages.
class ExtensionMetaChips extends StatelessWidget {
  final List<rust.ExtensionKind> kinds;
  final Set<rust.MediaType> mediaTypes;
  final bool nsfw;
  final List<String> languages;

  /// Render kind badges as their icon alone (with a tooltip) instead of
  /// icon plus label, keeping list tiles compact.
  final bool iconOnlyKinds;

  /// Languages shown before the remainder collapses into a "+N" badge.
  /// Zero shows all.
  final int maxLanguages;

  const ExtensionMetaChips({
    super.key,
    required this.kinds,
    required this.mediaTypes,
    this.nsfw = false,
    this.languages = const [],
    this.iconOnlyKinds = false,
    this.maxLanguages = 0,
  });

  @override
  Widget build(BuildContext context) {
    final shownLanguages = maxLanguages > 0 && languages.length > maxLanguages
        ? languages.sublist(0, maxLanguages)
        : languages;
    final hiddenLanguageCount = languages.length - shownLanguages.length;
    return Wrap(
      spacing: DionSpacing.xs,
      runSpacing: DionSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final kind in kinds)
          _MetaBadge(
            background: context.theme.colorScheme.secondaryContainer,
            child: Tooltip(
              message: kind.label,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    kind.icon,
                    size: 12,
                    color: context.theme.colorScheme.onSecondaryContainer,
                  ),
                  if (!iconOnlyKinds) ...[
                    const SizedBox(width: 2),
                    Text(
                      kind.label,
                      style: context.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        // Only entry providers deal in media; other kinds would inherit a
        // misleading type.
        if (kinds.contains(rust.ExtensionKind.entryProvider))
          for (final type in mediaTypes)
            Tooltip(
              message: type.name,
              child: Icon(
                type.icon,
                size: 14,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
        if (nsfw)
          _MetaBadge(
            background: context.theme.colorScheme.errorContainer,
            child: Text(
              '18+',
              style: context.bodySmall?.copyWith(
                color: context.theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        for (final lang in shownLanguages)
          _MetaBadge(child: Text(lang.toUpperCase(), style: context.bodySmall)),
        if (hiddenLanguageCount > 0)
          _MetaBadge(
            child: Tooltip(
              message: languages.skip(maxLanguages).join(', '),
              child: Text(
                '+$hiddenLanguageCount',
                style: context.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final Widget child;
  final Color? background;

  const _MetaBadge({required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background ?? context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DionRadius.sm),
      ),
      child: child,
    );
  }
}
