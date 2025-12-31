import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/custom_ui.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/utils/string.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';

import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart' show Colors, FontWeight, Icons;
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
      ].whereType<Widget>().toList(),
    ).paddingSymmetric(horizontal: 20, vertical: 24);
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isWide = context.width > 700;
    final coverSize = isWide ? 130.0 : 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image Card
        if (entry.cover != null)
          Container(
            width: coverSize,
            height: coverSize * 1.45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.12,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: DionImage(
              hasPopup: true,
              imageUrl: entry.cover!.url,
              httpHeaders: entry.cover!.header,
              boxFit: BoxFit.cover,
              errorWidget: Container(
                color: context.theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.25,
                  ),
                ),
              ),
            ),
          ).paddingOnly(right: 16),

        // Title, Author, Meta, and Stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: isWide ? 26 : 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 6),

              // Author
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

              // Extension and Status row
              Row(
                children: [
                  // Extension info
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
                            hasPopup: false,
                            imageUrl: entry.extension!.data.icon,
                            width: 12,
                            height: 12,
                            errorWidget: Icon(
                              Icons.extension,
                              size: 12,
                              color: context.theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 5),
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
                    ),
                    const SizedBox(width: 8),
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
              ),

              const SizedBox(height: 10),

              // Rating and Views inline
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
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (entry.rating! * 5).toStringAsFixed(1),
                        style: context.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (entry.views != null) ...[
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: context.theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ],
                    ],
                    if (entry.views != null) ...[
                      Icon(
                        Icons.visibility_outlined,
                        size: 13,
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(width: 4),
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
                    GoRouter.of(
                      context,
                    ).replace('/detail', extra: [entryDetailed]);
                  }
                } else if (entry is EntryDetailed) {
                  final saved = await (entry as EntryDetailed).toSaved();
                  if (context.mounted) {
                    GoRouter.of(context).replace('/detail', extra: [saved]);
                  }
                }
              }
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInLibrary ? Icons.check_circle : Icons.add_circle_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
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

  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section divider
        Container(
          height: 1,
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ).paddingOnly(bottom: 20),

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

  Widget _buildCustomUISection(BuildContext context) {
    return isEntryDetailed(
      context: context,
      entry: entry,
      isdetailed: (entry) {
        if (entry.ui == null || entry.ui.isEmpty || entry.extension == null) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: context.theme.colorScheme.onSurface.withValues(
                alpha: 0.05,
              ),
              width: 0.5,
            ),
          ),
          child: CustomUIWidget.fromUI(
            ui: entry.ui!,
            extension: entry.extension!,
          ),
        ).paddingOnly(bottom: 20);
      },
      shimmer: false,
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
