import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart'
    show CustomUI, Extension, ExtensionService;
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/custom_ui.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/utils/string.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/views/detail/library_picker.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';

import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart' show Colors, FontWeight, Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class EntryInfo extends StatelessWidget {
  final Entry entry;
  const EntryInfo({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry is EntryDetailed &&
            ((entry as EntryDetailed).extension == null))
          _buildWarningBox(context, message: 'Extension not found'),
        if (entry is EntryDetailed &&
            !((entry as EntryDetailed).extension?.isenabled ?? true))
          _buildWarningBox(
            context,
            message: 'Extension disabled',
            buttonText: 'Enable',
            onTap: () async {
              await (entry as EntryDetailed).extension?.enable();
            },
          ),
        _buildHeaderSection(context),
        _buildGenresSection(context),
        _buildLibraryButton(context),
        _buildDescriptionSection(context),
        _buildCustomUISection(context),
        if (entry is EntryDetailed) ChapterInfo(entry: entry as EntryDetailed),
      ].whereType<Widget>().toList(),
    ).paddingSymmetric(horizontal: 20, vertical: 12);
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isWide = !context.isCompactWindow;
    final coverSize = isWide ? 180.0 : 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.cover != null)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: coverSize,
              maxHeight: coverSize,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.17,
                    ),
                    blurRadius: 12,
                    offset: const Offset(4, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: DionImage(
                hasPopup: true,
                imageUrl: entry.cover!.url,
                httpHeaders: entry.cover!.header,
                boxFit: BoxFit.cover,
              ),
            ),
          ).paddingOnly(right: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: isWide ? 26 : 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: context.theme.colorScheme.onSurface,
                ),
              ).paddingOnly(bottom: 6),

              if (entry.author != null && entry.author!.isNotEmpty)
                Text(
                  entry.author!
                      .map((e) => e.trim().replaceAll('\n', ''))
                      .reduce((a, b) => '$a, $b'),
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.1,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.55,
                    ),
                  ),
                ).paddingOnly(bottom: 10),

              Row(
                children: [
                  if (entry.extension != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DionImage(
                            imageUrl: entry.extension!.data.icon,
                            width: 12,
                            height: 12,
                            errorWidget: Icon(
                              Icons.extension,
                              size: 12,
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ).paddingOnly(right: 5),
                          Text(
                            entry.extension!.data.name,
                            style: context.labelSmall?.copyWith(
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ).paddingOnly(right: 8),
                  ],

                  // Status
                  isEntryDetailed(
                    context: context,
                    entry: entry,
                    isdetailed: (entry) => Text(
                      entry.status.asString().toUpperCase(),
                      style: context.labelSmall?.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    isnt: () => Text(
                      'UNKNOWN',
                      style: context.labelSmall?.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ).paddingOnly(bottom: 10),

              if (entry.rating != null || entry.views != null)
                Row(
                  children: [
                    if (entry.rating != null) ...[
                      // Announces "Rating x of 5" on its own.
                      Stardisplay(
                        width: 14,
                        height: 14,
                        fill: entry.rating ?? 0,
                        color: const Color(0xFFE5A500),
                        bgcolor: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.15,
                        ),
                      ).paddingOnly(right: 6),
                      // Duplicates the star rating, so it is excluded to
                      // avoid reading it twice.
                      ExcludeSemantics(
                        child: Text(
                          (entry.rating! * 5).toStringAsFixed(1),
                          style: context.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ).paddingOnly(right: 4),
                      if (entry.views != null) ...[
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: context.theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ).paddingOnly(right: 4),
                      ],
                    ],
                    if (entry.views != null) ...[
                      Semantics(
                        label:
                            '${NumberFormat.compact().format(entry.views)} views',
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ).paddingOnly(right: 4),
                            Text(
                              NumberFormat.compact().format(entry.views),
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: context.theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    ).paddingOnly(bottom: 20);
  }

  Widget _buildGenresSection(BuildContext context) {
    return isEntryDetailed(
      context: context,
      entry: entry,
      isdetailed: (entry) {
        if (entry.genres == null || entry.genres!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: entry.genres!
              .map((e) => _buildGenreChip(context, e))
              .toList(),
        ).paddingOnly(bottom: 20);
      },
      isnt: () => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: getWords(4).map((e) => _buildGenreChip(context, e)).toList(),
      ).paddingOnly(bottom: 20),
    );
  }

  Widget _buildGenreChip(BuildContext context, String genre) {
    final chipColor = getColor(
      genre.toUpperCase(),
      saturation: 35,
      brightness: 55,
    );
    return Container(
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        genre.toUpperCase(),
        style: context.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.95),
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildLibraryButton(BuildContext context) {
    return _LibraryButton(entry: entry);
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) {
            if (entry.description.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Foldabletext(
              maxLines: 5,
              entry.description.trim(),
              style: context.bodyMedium?.copyWith(
                height: 1.7,
                letterSpacing: 0.15,
                fontWeight: FontWeight.w400,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
            );
          },
          isnt: () => Text(
            getText(70),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: context.bodyMedium?.copyWith(
              height: 1.7,
              letterSpacing: 0.15,
              fontWeight: FontWeight.w400,
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    ).paddingOnly(bottom: 24);
  }

  Widget _buildCustomUIContainer(
    BuildContext context, {
    required CustomUI ui,
    required Extension extension,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: CustomUIWidget.fromUI(ui: ui, extension: extension),
    ).paddingOnly(bottom: 20);
  }

  Widget _buildCustomUISection(BuildContext context) {
    return Center(
      child: isEntryDetailed(
        context: context,
        entry: entry,
        isdetailed: (entry) {
          final children = <Widget>[];
          if (entry.ui != null &&
              !entry.ui.isEmpty &&
              entry.extension != null) {
            children.add(
              _buildCustomUIContainer(
                context,
                ui: entry.ui!,
                extension: entry.extension!,
              ),
            );
          }
          if (entry is EntrySaved) {
            for (final ext in entry.entryExtensions) {
              if (ext.ui == null || ext.ui!.isEmpty || ext.extension == null) {
                continue;
              }
              children.add(
                _buildCustomUIContainer(
                  context,
                  ui: ext.ui!,
                  extension: ext.extension!,
                ),
              );
            }
            for (final ext in entry.sourceExtensions) {
              if (ext.ui == null || ext.ui!.isEmpty || ext.extension == null) {
                continue;
              }
              children.add(
                _buildCustomUIContainer(
                  context,
                  ui: ext.ui!,
                  extension: ext.extension!,
                ),
              );
            }
          }
          if (children.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        },
        shimmer: false,
      ),
    );
  }

  Widget _buildWarningBox(
    BuildContext context, {
    required String message,
    String? buttonText,
    FutureOr<void> Function()? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.error.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: context.theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.bodySmall?.copyWith(
                color: context.theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (buttonText != null)
            DionTextbutton(
              type: ButtonType.ghost,
              color: context.theme.colorScheme.error,
              onPressed: onTap,
              child: Text(
                buttonText,
                style: context.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    ).paddingOnly(bottom: 16);
  }
}

Widget isEntryDetailed({
  required BuildContext context,
  required Entry entry,
  required Widget Function(EntryDetailed e) isdetailed,
  Widget Function()? isnt,
  bool shimmer = true,
}) {
  isnt ??= () => Container(color: Colors.white);
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(child: isnt()).applyShimmer(
    highlightColor: context.scaffoldBackgroundColor.lighten(20),
    baseColor: context.theme.scaffoldBackgroundColor,
  );
}

class ChapterInfo extends StatefulWidget {
  final EntryDetailed entry;

  const ChapterInfo({super.key, required this.entry});

  @override
  State<ChapterInfo> createState() => _ChapterInfoState();
}

class _ChapterInfoState extends State<ChapterInfo> {
  late Future<_DownloadInfoData> _downloadInfo = _calculateDownloadInfo();

  @override
  void didUpdateWidget(covariant ChapterInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry != widget.entry) {
      setState(() {
        _downloadInfo = _calculateDownloadInfo();
      });
    }
  }

  Future<_DownloadInfoData> _calculateDownloadInfo() async {
    final entry = widget.entry;
    final downloadService = locate<DownloadService>();
    int downloadedCount = 0;

    for (int i = 0; i < entry.episodes.length; i++) {
      final episodePath = EpisodePath(entry, i);
      if (await downloadService.isDownloaded(episodePath)) {
        downloadedCount++;
      }
    }

    int totalSize = 0;
    if (downloadedCount > 0) {
      final downloadPath = locate<DirectoryProvider>().downloadspath
          .sub(pathEncode(entry.boundExtensionId))
          .sub(pathEncode(entry.id.uid));
      totalSize = await getDirectorySize(downloadPath);
    }

    return _DownloadInfoData(
      downloadedCount: downloadedCount,
      totalSize: totalSize,
    );
  }

  Widget _metaText(BuildContext context, String text) {
    return Text(
      text,
      style: context.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: context.theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }

  Widget buildChapterCount(BuildContext context) {
    return _metaText(
      context,
      '${widget.entry.episodes.length} ${widget.entry.mediaType.getEpisodeNames(widget.entry.episodes.length)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    if (entry is! EntrySaved) {
      return buildChapterCount(context);
    }
    return FutureBuilder<_DownloadInfoData>(
      future: _downloadInfo,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final hasDownloads = data != null && data.downloadedCount > 0;
        final parts = <Widget>[
          buildChapterCount(context),
          if (hasDownloads)
            _metaText(
              context,
              '${data.downloadedCount} ${entry.mediaType.getEpisodeNames(data.downloadedCount)} downloaded',
            ),
          if (hasDownloads) _metaText(context, formatBytes(data.totalSize)),
          if (entry.lastRefreshed != null)
            _metaText(
              context,
              'Refreshed ${entry.lastRefreshed!.formatrelative()}',
            ),
        ];
        // Wrap instead of Row so the metadata line folds onto a second line on
        // narrow windows instead of overflowing; each bullet stays glued to
        // its text.
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (index, part) in parts.indexed)
              if (index == 0)
                part
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _metaText(context, '•'),
                    const SizedBox(width: 8),
                    part,
                  ],
                ),
          ],
        );
      },
    );
  }
}

class _DownloadInfoData {
  final int downloadedCount;
  final int totalSize;

  _DownloadInfoData({required this.downloadedCount, required this.totalSize});
}

class _LibraryButton extends StatefulWidget {
  final Entry entry;
  const _LibraryButton({required this.entry});

  @override
  State<_LibraryButton> createState() => _LibraryButtonState();
}

class _LibraryButtonState extends State<_LibraryButton> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _pickerEntry;

  bool get _isInLibrary => widget.entry is EntrySaved;
  bool get _isEnabled => widget.entry is EntryDetailed;

  void _showPicker() {
    if (_pickerEntry != null || !_isEnabled) return;
    final entry = widget.entry as EntryDetailed;
    // Measure the button's rect relative to the overlay the picker will be
    // inserted into; the picker positions itself statically from this rect.
    final overlay = Overlay.of(context, rootOverlay: true);
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final anchor = buttonBox == null
        ? Rect.zero
        : Rect.fromPoints(
            buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox),
            buttonBox.localToGlobal(
              buttonBox.size.bottomRight(Offset.zero),
              ancestor: overlayBox,
            ),
          );
    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => LibrarySaveSheet(
        anchor: anchor,
        entry: entry,
        onDismiss: _removePicker,
        onCommit: (result) {
          _removePicker();
          _applyPickerResult(result);
        },
      ),
    );
    setState(() {
      _pickerEntry = overlayEntry;
    });
    overlay.insert(overlayEntry);
  }

  void _removePicker() {
    _pickerEntry?.remove();
    _pickerEntry = null;
  }

  Future<void> _applyPickerResult(LibraryPickerResult result) async {
    final entry = widget.entry;
    if (entry is EntrySaved) {
      await _applyToSaved(entry, result);
    } else if (entry is EntryDetailed) {
      await _saveNew(entry, result);
    }
  }

  Future<void> _applyToSaved(
    EntrySaved entry,
    LibraryPickerResult result,
  ) async {
    entry.entryExtensions = _diffExtensions(
      entry.entryExtensions,
      result.entryExtensionIds,
    );
    entry.sourceExtensions = _diffExtensions(
      entry.sourceExtensions,
      result.sourceExtensionIds,
    );
    entry.categories = result.categories;
    await entry.save();
    if (mounted) {
      context.replace('/detail', extra: [entry]);
    }
  }

  Future<void> _saveNew(EntryDetailed entry, LibraryPickerResult result) async {
    // The picker's ticks are the explicit decision, so auto-add rules are not
    // applied on top of them here (they already pre-ticked the defaults).
    final saved = await entry.toSavedWithCategories(
      result.categories,
      applyRules: false,
    );
    await _attachTicked(saved, result.entryExtensionIds, result);
    saved.sourceExtensions = _diffExtensions(
      const [],
      result.sourceExtensionIds,
    );
    await saved.save();
    if (mounted) {
      context.replace('/detail', extra: [saved]);
    }
  }

  Future<void> _attachTicked(
    EntrySaved entry,
    Set<String> ids,
    LibraryPickerResult result,
  ) async {
    for (final id in ids) {
      final ext = locate<ExtensionService>().tryGetExtension(id);
      if (ext == null) continue;
      entry.entryExtensions = [
        ...entry.entryExtensions,
        EntryExtension(extensionId: id, extensionSettings: {}),
      ];
      if (ext.getExtensionTypeOrNull<rust.ExtensionType_EntryProcessor>() !=
          null) {
        try {
          await entry.extension?.refreshEntryExtension(entry, ext);
        } catch (e) {
          logger.w(
            'Failed to refresh newly added entry extension $id',
            error: e,
          );
        }
      }
    }
  }

  List<EntryExtension> _diffExtensions(
    List<EntryExtension> current,
    Set<String> wantedIds,
  ) {
    return [
      ...current.where((e) => wantedIds.contains(e.extensionId)),
      for (final id in wantedIds)
        if (!current.any((e) => e.extensionId == id))
          EntryExtension(extensionId: id, extensionSettings: {}),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: _isEnabled ? (details) => _showPicker() : null,
      child: SizedBox(
        key: _buttonKey,
        width: double.infinity,
        child: DionTextbutton(
          type: _isInLibrary ? ButtonType.elevated : ButtonType.filled,
          onPressed: _isEnabled
              ? () async {
                  final router = GoRouter.of(context);
                  if (widget.entry is EntrySaved) {
                    final entryDetailed = await (widget.entry as EntrySaved)
                        .toDetailed();
                    await (widget.entry as EntrySaved).delete();
                    if (mounted) {
                      router.replace('/detail', extra: [entryDetailed]);
                    }
                  } else if (widget.entry is EntryDetailed) {
                    final saved = await (widget.entry as EntryDetailed)
                        .toSaved();
                    if (mounted) {
                      router.replace('/detail', extra: [saved]);
                    }
                  }
                }
              : null,
          onLongPress: _isEnabled ? _showPicker : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInLibrary ? Icons.check_circle : Icons.add_circle_outline,
                size: 18,
              ).paddingOnly(right: 8),
              Text(
                _isInLibrary ? 'IN LIBRARY' : 'ADD TO LIBRARY',
                style: context.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ).paddingOnly(bottom: 28);
  }
}
