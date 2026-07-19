import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart' show Extension, CustomUI;
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/custom_ui.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/utils/string.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';

import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dion_textbox.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart'
    show Colors, FontWeight, Icons, showDialog;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final isWide = context.width > 700;
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
                      Stardisplay(
                        width: 14,
                        height: 14,
                        fill: entry.rating ?? 0,
                        color: const Color(0xFFE5A500),
                        bgcolor: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.15,
                        ),
                      ).paddingOnly(right: 6),
                      Text(
                        (entry.rating! * 5).toStringAsFixed(1),
                        style: context.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
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
                      Icon(
                        Icons.visibility_outlined,
                        size: 13,
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ).paddingOnly(right: 4),
                      Text(
                        NumberFormat.compact().format(entry.views),
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
    final isInLibrary = entry is EntrySaved;
    final isEnabled = entry is EntryDetailed;
    return SizedBox(
      width: double.infinity,
      child: DionTextbutton(
        type: isInLibrary ? ButtonType.elevated : ButtonType.filled,
        onPressed: isEnabled
            ? () async {
                if (entry is EntrySaved) {
                  final entryDetailed = await (entry as EntrySaved)
                      .toDetailed();
                  await (entry as EntrySaved).delete();
                  if (context.mounted) {
                    context.replace('/detail', extra: [entryDetailed]);
                  }
                } else if (entry is EntryDetailed) {
                  final saved = await (entry as EntryDetailed).toSaved();
                  if (context.mounted) {
                    context.replace('/detail', extra: [saved]);
                  }
                }
              }
            : null,
        onLongPress: isEnabled ? () => _showCategoriesDialog(context) : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInLibrary ? Icons.check_circle : Icons.add_circle_outline,
              size: 18,
            ).paddingOnly(right: 8),
            Text(
              isInLibrary ? 'IN LIBRARY' : 'ADD TO LIBRARY',
              style: context.labelMedium?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).paddingOnly(bottom: 28);
  }

  Future<void> _showCategoriesDialog(BuildContext context) async {
    final initialCategories = entry is EntrySaved
        ? (entry as EntrySaved).categories
        : const <Category>[];
    final result = await showDialog<List<Category>>(
      context: context,
      builder: (context) =>
          _CategoryChooserDialog(initialCategories: initialCategories),
    );
    if (result == null) return;
    if (!context.mounted) return;

    if (entry is EntrySaved) {
      // Already in library: just update the categories.
      final saved = entry as EntrySaved;
      saved.categories = result;
      await saved.save();
      if (context.mounted) {
        context.replace('/detail', extra: [saved]);
      }
    } else if (entry is EntryDetailed) {
      // Not yet in library: add it with the chosen categories.
      final saved = await (entry as EntryDetailed).toSavedWithCategories(
        result,
      );
      if (context.mounted) {
        context.replace('/detail', extra: [saved]);
      }
    }
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
        color: context.theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(
            alpha: 0.05,
          ),
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
              if (ext.ui == null ||
                  ext.ui!.isEmpty ||
                  ext.extension == null) {
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
              if (ext.ui == null ||
                  ext.ui!.isEmpty ||
                  ext.extension == null) {
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

class ChapterInfo extends StatelessWidget {
  final EntryDetailed entry;

  const ChapterInfo({super.key, required this.entry});

  Future<_DownloadInfoData> _calculateDownloadInfo() async {
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

  Widget buildChapterCount(BuildContext context) {
    return Text(
      '${entry.episodes.length} ${entry.mediaType.getEpisodeNames(entry.episodes.length)}',
      style: context.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: context.theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entry is! EntrySaved) {
      return buildChapterCount(context);
    }
    return FutureBuilder<_DownloadInfoData>(
      future: _calculateDownloadInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.downloadedCount == 0) {
          return buildChapterCount(context);
        }

        final data = snapshot.data!;
        final sizeString = formatBytes(data.totalSize);

        return Row(
          children: [
            buildChapterCount(context),
            const SizedBox(width: 8),
            Text(
              '•',
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${data.downloadedCount} ${entry.mediaType.getEpisodeNames(data.downloadedCount)} downloaded',
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              sizeString,
              style: context.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
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

class _CategoryChooserDialog extends StatefulWidget {
  final List<Category> initialCategories;

  const _CategoryChooserDialog({required this.initialCategories});

  @override
  State<_CategoryChooserDialog> createState() => _CategoryChooserDialogState();
}

class _CategoryChooserDialogState extends State<_CategoryChooserDialog> {
  late MultiDropdownController<Category> _controller;
  bool _loading = true;
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MultiDropdownController<Category>();
    _loadCategories();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await locate<Database>().getCategories();
    _controller.setItems(
      categories.map((e) => MultiDropdownItem(label: e.name, value: e)),
    );
    _controller.selectWhere(
      (item) => widget.initialCategories.contains(item.value),
    );
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    final db = locate<Database>();
    final categories = await db.getCategories();
    final category = Category.construct(name, categories.length);
    await db.updateCategory(category);
    _controller.add(
      MultiDropdownItem.active(label: category.name, value: category),
    );
    _newCategoryController.clear();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DionDialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Categories',
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ).paddingOnly(bottom: 4),
              Text(
                'Pick the categories to add this entry to.',
                style: context.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.55,
                  ),
                ),
              ).paddingOnly(bottom: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: DionProgressBar()),
                )
              else ...[
                DionMultiDropdown(
                  controller: _controller,
                  defaultItem: Text(
                    'Choose categories',
                    style: context.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ).paddingOnly(bottom: 12),
                Row(
                  children: [
                    Expanded(
                      child: DionTextbox(
                        controller: _newCategoryController,
                        hintText: 'New category',
                        onSubmitted: (_) => _addCategory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DionIconbutton(
                      icon: const Icon(Icons.add),
                      onPressed: _addCategory,
                    ),
                  ],
                ).paddingOnly(bottom: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DionTextbutton(
                      type: ButtonType.ghost,
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ).paddingOnly(right: 8),
                    DionTextbutton(
                      onPressed: () {
                        final selection = _controller.selected
                            .where((e) => e.selected)
                            .map((e) => e.value)
                            .toList();
                        Navigator.pop(context, selection);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
