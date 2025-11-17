import 'dart:async';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/CustomUI.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/utils/color.dart';
import 'package:dionysos/utils/placeholder.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/views/detail/detail.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/columnrow.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart' show ButtonStyle, Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EntryInfo extends StatelessWidget {
  final Entry entry;
  const EntryInfo({super.key, required this.entry});

  //TODO: Extract this into a seperate Widget
  Widget buildWarningBox(
    BuildContext context, {
    required String message,
    String? buttonText,
    FutureOr<void> Function()? onTap,
  }) {
    return ColoredBox(
      color: context.theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: context.theme.colorScheme.error,
          ).paddingOnly(right: 5),
          Text(
            message,
            style: context.bodyLarge!.copyWith(
              color: context.theme.colorScheme.onErrorContainer,
            ),
          ),
          if (buttonText != null) const Spacer(),
          if (buttonText != null)
            DionTextbutton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(
                  context.theme.colorScheme.onErrorContainer,
                ),
              ),
              onPressed: onTap,
              child: Text(buttonText),
            ),
        ],
      ).paddingAll(5),
    ).paddingAll(5);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 6, left: 5, right: 7),
      children: [
        if (entry is EntryDetailed &&
            ((entry as EntryDetailed).extension == null))
          buildWarningBox(context, message: 'Warning: Extension is not found'),
        if (entry is EntryDetailed &&
            !((entry as EntryDetailed).extension?.isenabled ?? true))
          buildWarningBox(
            context,
            message: 'Warning: Extension Disabled',
            buttonText: 'Enable',
            onTap: () async {
              await (entry as EntryDetailed).extension?.enable();
            },
          ),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DionImage(
                alignment: Alignment.center,
                imageUrl: entry.cover?.url,
                httpHeaders: entry.cover?.header,
                borderRadius: BorderRadius.circular(3),
                filterQuality: FilterQuality.high,
                hasPopup: true,
                width: (context.width > 500) ? 200 : 150,
              ).paddingAll(3),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: (context.width > 950)
                        ? context.headlineLarge
                        : context.headlineSmall,
                    // pauseBetween: 1.seconds,
                  ),
                  if (entry.author != null && entry.author!.isNotEmpty)
                    DionTextScroll(
                      'by ${(entry.author != null && entry.author!.isNotEmpty) ? entry.author!.map((e) => e.trim().replaceAll('\n', '')).reduce((a, b) => '$a • $b') : 'Unkown author'}',
                      style: context.labelLarge?.copyWith(color: Colors.grey),
                    ),
                  Row(
                    children: [
                      if (entry.extension != null) ...[
                        DionImage(
                          imageUrl: entry.extension!.data.icon,
                          width: 15,
                          height: 15,
                          errorWidget: const Icon(Icons.image, size: 20),
                        ).paddingOnly(right: 5),
                        DionTextScroll(
                          entry.extension!.data.name,
                          style: context.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: context.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      isEntryDetailed(
                        context: context,
                        entry: entry,
                        isdetailed: (entry) => Text(
                          entry.status.asString(),
                          style: context.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        isnt: () =>
                            Text('Releasing', style: context.bodyMedium),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (entry.rating != null || entry.views != null)
                    SizedBox(
                      height: (context.width > 950) ? 50 : 80,
                      child: DionBadge(
                        noMargin: true,
                        child: ColumnRow(
                          isRow: context.width > 950,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (entry.rating != null)
                              Stardisplay(
                                width: 25,
                                height: 25,
                                fill: entry.rating ?? 1,
                                color: Colors.yellowAccent,
                              ).paddingOnly(right: 5).toCenter(),
                            RichText(
                              text: TextSpan(
                                children: [
                                  if (entry.rating != null &&
                                      context.width > 1200)
                                    TextSpan(
                                      text:
                                          '${(entry.rating! * 5).toStringAsFixed(2)} Stars (',
                                      style: context.bodyLarge,
                                    ),
                                  if (entry.views != null)
                                    TextSpan(
                                      text:
                                          '${NumberFormat.compact().format(entry.views)} Views',
                                      style: context.bodyLarge,
                                    ),
                                  if (entry.rating != null &&
                                      context.width > 1200)
                                    TextSpan(
                                      text: ')',
                                      style: context.bodyLarge,
                                    ),
                                ],
                              ),
                            ).toCenter(),
                          ],
                        ).paddingAll(5),
                      ),
                    ),
                ],
              ).paddingOnly(bottom: 5, left: 5).expanded(),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: isEntryDetailed(
            context: context,
            entry: entry,
            isdetailed: (entry) => ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children:
                  entry.genres
                      ?.map(
                        (e) => DionBadge(
                          color: getColor(e),
                          child: Center(child: Text(e)),
                        ),
                      )
                      .toList() ??
                  [],
            ),
            isnt: () => Row(
              children: getWords(
                4,
              ).map((e) => DionBadge(child: Center(child: Text(e)))).toList(),
            ),
          ),
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => DionIconbutton(
            icon: Icon(
              entry is EntrySaved ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
            onPressed: () async {
              if (entry is EntrySaved) {
                final entrydetailed = await entry.delete();
                if (context.mounted) {
                  GoRouter.of(
                    context,
                  ).replace('/detail', extra: [entrydetailed]);
                }
              } else {
                final saved = await entry.toSaved();
                if (context.mounted) {
                  GoRouter.of(context).replace('/detail', extra: [saved]);
                }
              }
            },
          ),
          isnt: () => DionIconbutton(
            icon: Icon(
              entry is EntrySaved ? Icons.library_books : Icons.library_add,
              size: 30,
            ),
          ),
          shimmer: false,
        ),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => Foldabletext(
            maxLines: 7,
            entry.description.trim(),
            style: context.bodyMedium,
          ),
          isnt: () => Text(maxLines: 7, getText(70), style: context.bodyMedium),
        ).paddingOnly(top: 7),
        isEntryDetailed(
          context: context,
          entry: entry,
          isdetailed: (entry) => entry.ui.isEmpty || entry.extension == null
              ? nil
              : DionBadge(
                  child: CustomUIWidget(
                    ui: entry.ui,
                    extension: entry.extension!,
                  ),
                ).paddingAll(5),
          isnt: () => nil,
          shimmer: false,
        ),
      ],
    );
  }
}
