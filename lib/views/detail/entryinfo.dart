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
import 'package:dionysos/widgets/container/container.dart';

import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart'
    show Colors, FontWeight, Icons, TextButton;
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
          _buildWarningBox(context, message: 'Warning: Extension is not found'),
        if (entry is EntryDetailed &&
            !((entry as EntryDetailed).extension?.isenabled ?? true))
          _buildWarningBox(
            context,
            message: 'Warning: Extension Disabled',
            buttonText: 'Enable',
            onTap: () async {
              await (entry as EntryDetailed).extension?.enable();
            },
          ),
        _buildEditorialHeader(context),
        _buildMetadataSection(context),
        _buildDescriptionSection(context),
        _buildCustomUISection(context),
      ].whereType<Widget>().toList(),
    ).paddingSymmetric(horizontal: 16, vertical: 16);
  }

  Widget _buildEditorialHeader(BuildContext context) {
    final isWide = context.width > 700;
    final coverSize = isWide ? 140.0 : 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover Image
        if (entry.cover != null)
          Container(
            width: coverSize,
            height: coverSize * 1.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.15,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                  Icons.broken_image,
                  size: 32,
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
          ).paddingOnly(right: 20),

        // Title and Metadata
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: isWide ? 38 : 28,
                  height: 1.15,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.5,
                  color: context.theme.colorScheme.onSurface,
                ),
              ).paddingOnly(bottom: 8),

              if (entry.author != null && entry.author!.isNotEmpty)
                Text(
                  'by ${entry.author!.map((e) => e.trim().replaceAll('\n', '')).reduce((a, b) => '$a • $b')}',
                  style: context.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ).paddingOnly(bottom: 14),

              // Extension and Status row
              Row(
                children: [
                  if (entry.extension != null) ...[
                    DionImage(
                      hasPopup: true,
                      imageUrl: entry.extension!.data.icon,
                      width: 16,
                      height: 16,
                      errorWidget: const Icon(Icons.image, size: 16),
                    ).paddingOnly(right: 6),
                    Text(
                      entry.extension!.data.name,
                      style: context.labelMedium?.copyWith(
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ).paddingSymmetric(horizontal: 10),
                  ],
                  isEntryDetailed(
                    context: context,
                    entry: entry,
                    isdetailed: (entry) => Text(
                      entry.status.asString().toUpperCase(),
                      style: context.labelMedium?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    isnt: () => Text(
                      'RELEASING',
                      style: context.labelMedium?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).paddingOnly(bottom: 24);
  }

  Widget _buildMetadataSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genres
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                entry.genres
                    ?.map((e) => _buildGenreChip(context, e))
                    .toList() ??
                [],
          ).paddingOnly(bottom: 18),
          isnt: () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: getWords(
              4,
            ).map((e) => _buildGenreChip(context, e)).toList(),
          ).paddingOnly(bottom: 18),
        ),

        // Stats Card
        if (entry.rating != null || entry.views != null)
          _buildStatsCard(context).paddingOnly(bottom: 24),

        // Library Button
        _buildLibraryButton(context).paddingOnly(bottom: 8),
      ],
    );
  }

  Widget _buildGenreChip(BuildContext context, String genre) {
    return Container(
      decoration: BoxDecoration(
        color: getColor(genre.toUpperCase(), saturation: 45, brightness: 60),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        genre.toUpperCase(),
        style: context.labelSmall?.copyWith(
          color: context.theme.colorScheme.onPrimary,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.rating != null) ...[
            Stardisplay(
              width: 22,
              height: 22,
              fill: entry.rating ?? 1,
              color: const Color(0xFFFFB800),
            ).paddingOnly(right: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (entry.rating! * 5).toStringAsFixed(1),
                  style: context.titleLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
                Text(
                  'RATING',
                  style: context.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontSize: 8.5,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (entry.views != null)
              Container(
                width: 1,
                height: 32,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.1,
                ),
              ).paddingSymmetric(horizontal: 18),
          ],
          if (entry.views != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  NumberFormat.compact().format(entry.views),
                  style: context.titleLarge?.copyWith(
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
                Text(
                  'VIEWS',
                  style: context.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontSize: 8.5,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLibraryButton(BuildContext context) {
    final isInLibrary = entry is EntrySaved;
    final isEnabled = entry is EntryDetailed;

    return SizedBox(
      width: double.infinity,
      child: DionTextbutton(
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
              isInLibrary
                  ? Icons.check_circle_outline
                  : Icons.add_circle_outline,
              size: 20,
            ).paddingOnly(right: 8),
            Text(
              isInLibrary ? 'IN LIBRARY' : 'ADD TO LIBRARY',
              style: context.labelLarge?.copyWith(
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
                color: context.theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return isEntryDetailed(
      context: context,
      entry: entry,
      isdetailed: (entry) => Foldabletext(
        maxLines: 6,
        entry.description.trim(),
        style: context.bodyMedium?.copyWith(
          height: 1.65,
          letterSpacing: 0.15,
          fontWeight: FontWeight.w400,
        ),
      ).paddingOnly(bottom: 16),
      isnt: () => Text(
        getText(70),
        maxLines: 6,
        style: context.bodyMedium?.copyWith(
          height: 1.65,
          letterSpacing: 0.15,
          fontWeight: FontWeight.w400,
        ),
      ).paddingOnly(bottom: 16),
    );
  }

  Widget _buildCustomUISection(BuildContext context) {
    return isEntryDetailed(
      context: context,
      entry: entry,
      isdetailed: (entry) =>
          (entry.ui == null || entry.ui.isEmpty || entry.extension == null)
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: context.theme.colorScheme.onSurface.withValues(
                    alpha: 0.06,
                  ),
                  width: 0.5,
                ),
              ),
              child: CustomUIWidget.fromUI(
                ui: entry.ui!,
                extension: entry.extension!,
              ),
            ).paddingOnly(bottom: 16),
      shimmer: false,
    );
  }

  Widget _buildWarningBox(
    BuildContext context, {
    required String message,
    String? buttonText,
    FutureOr<void> Function()? onTap,
  }) {
    return DionContainer(
      color: context.theme.colorScheme.errorContainer,
      // padding: const EdgeInsets.all(12),
      // decoration: BoxDecoration(
      //   color: context.theme.colorScheme.errorContainer,
      //   borderRadius: BorderRadius.circular(3),
      // ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: context.theme.colorScheme.error,
          ).paddingOnly(right: 8),
          Expanded(
            child: Text(
              message,
              style: context.bodyLarge?.copyWith(
                color: context.theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (buttonText != null)
            DionTextbutton(
              color: context.theme.colorScheme.error,
              onPressed: onTap,
              child: Text(buttonText),
            ),
        ],
      ).paddingAll(8),
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
