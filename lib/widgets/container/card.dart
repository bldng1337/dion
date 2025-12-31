import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:country_flags/country_flags.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/container/container.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Card extends StatelessWidget {
  final String? imageUrl;
  final List<Widget>? leadingBadges;
  final List<Widget>? trailingBadges;
  final Map<String, String>? httpHeaders;
  final Widget? bottom;
  final Function()? onTap;
  const Card({
    super.key,
    required this.imageUrl,
    this.leadingBadges,
    this.trailingBadges,
    this.bottom,
    this.onTap,
    this.httpHeaders,
  });

  Widget buildCard(BuildContext context) {
    const double width = 300 / 1.5;
    const double height = 600 / 2;
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        DionImage(
          imageUrl: imageUrl,
          httpHeaders: httpHeaders,
          width: width,
          height: height,
          errorWidget: Icon(Icons.image, size: min(width, height)),
          boxFit: BoxFit.cover,
        ),
        Positioned(
          bottom: -1,
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  Theme.of(context).shadowColor.withValues(alpha: 0.45),
                  Theme.of(context).shadowColor.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.6, 0.8, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...(leadingBadges ?? []).map(
                      (e) => DionContainer(
                        type: ContainerType.filled,
                        color: context.theme.colorScheme.surfaceContainer,
                        child: e.paddingAll(3),
                      ).paddingAll(3),
                    ),
                    const Spacer(),
                    ...(trailingBadges ?? []).map(
                      (e) => DionContainer(
                        type: ContainerType.filled,
                        color: context.theme.colorScheme.surfaceContainer,
                        child: e.paddingAll(3),
                      ).paddingAll(3),
                    ),
                  ],
                ),
                const Spacer(),
                bottom ?? nil,
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      borderRadius: BorderRadius.circular(3),
      child: onTap != null
          ? Clickable(onTap: onTap, child: buildCard(context))
          : buildCard(context),
    ).paddingAll(4);
  }
}

class EntryCard extends StatelessWidget {
  final Entry entry;
  final bool showSaved;
  const EntryCard({super.key, required this.entry, this.showSaved = false});

  @override
  Widget build(BuildContext context) {
    final Entry entry = this.entry;
    return Card(
      imageUrl: entry.cover?.url,
      httpHeaders: entry.cover?.header,
      leadingBadges: [
        if (showSaved && entry is EntrySaved)
          Icon(
            Icons.bookmark,
            size: 15,
            color: context.theme.colorScheme.primary,
          ),
        if (entry is EntrySaved)
          Text(
            '${entry.latestEpisode}/${entry.totalEpisodes}${entry.status == ReleaseStatus.releasing ? '+' : ''}',
            style: context.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        if (entry.length != null && entry is! EntrySaved)
          Text(
            '${entry.length}',
            style: context.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        Icon(switch (entry.mediaType) {
          MediaType.audio => Icons.music_note,
          MediaType.video => Icons.videocam,
          MediaType.book => Icons.menu_book,
          MediaType.comic => Icons.image,
          MediaType.unknown => Icons.help,
        }, size: 15),
      ],
      trailingBadges: [
        if (entry is EntrySaved && entry.language.toLowerCase() != 'unknown')
          switch (FlagCode.fromCountryCode(entry.language)) {
            null => CountryFlag.fromLanguageCode(
              entry.language,
              height: 15,
              width: 15,
            ),
            _ => CountryFlag.fromCountryCode(
              entry.language,
              height: 15,
              width: 15,
            ),
          },
        DionImage(imageUrl: entry.extension?.data.icon, width: 15, height: 15),
      ],
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.rating != null)
            Row(
              children: [
                Stardisplay(
                  fill: entry.rating!,
                  width: 12,
                  height: 12,
                  color: Colors.white70,
                ),
                const Spacer(),
                if (entry.views != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye,
                        size: 13,
                        color: Colors.white70,
                      ).paddingOnly(right: 2),
                      Text(
                        NumberFormat.compact().format(entry.views),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
              ],
            ).paddingOnly(left: 5, right: 5),
          Text(
            entry.title.trim(),
            style: context.textTheme.titleSmall?.copyWith(color: Colors.white),
          ).paddingOnly(bottom: 5, left: 5),
        ],
      ),
      onTap: () {
        context.push(
          '/detail',
          extra: [entry],
        ); //TODO: Hack until i implement Codec for Entry
      },
    );
  }
}
