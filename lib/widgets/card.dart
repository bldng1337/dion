import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:country_flags/country_flags.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:text_scroll/text_scroll.dart';

const double width = 300 / 1.5;
const double height = 600 / 2;

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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: switch (context.diontheme.mode) {
        DionThemeMode.material => BorderRadius.zero,
        DionThemeMode.cupertino => BorderRadius.circular(5),
      },
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          if (imageUrl != null)
            DionImage(
              imageUrl: imageUrl,
              httpHeaders: httpHeaders,
              width: width,
              height: height,
              errorWidget: Icon(Icons.image, size: min(width, height)),
              boxFit: BoxFit.cover,
            )
          else
            Icon(Icons.image, size: min(width, height)),
          Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Theme.of(context).shadowColor.withOpacity(0.1),
                  Theme.of(context).shadowColor.withOpacity(0.5),
                  Theme.of(context).shadowColor.withOpacity(1),
                ],
                stops: const [0, 0.6, 0.75, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...(leadingBadges ?? []).map(
                      (e) => DionBadge(
                        child: e,
                      ),
                    ),
                    const Spacer(),
                    ...(trailingBadges ?? []).map(
                      (e) => DionBadge(
                        child: e,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                bottom ?? nil,
              ],
            ),
          ),
        ],
      ),
    ).onTap(onTap ?? () {}).paddingAll(5);
  }
}

class EntryCard extends StatelessWidget {
  final Entry entry;
  const EntryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      imageUrl: entry.cover,
      httpHeaders: entry.coverHeader,
      leadingBadges: [
        if (entry is EntrySaved)
          DionBadge(
            child: Text(
              '${(entry as EntrySaved).latestEpisode}/${(entry as EntrySaved).totalEpisodes}',
              style: context.textTheme.labelSmall,
            ),
          ),
        if (entry.length != null && entry is! EntrySaved)
          DionBadge(
            child: Text(
              entry.length!.toString(),
              style: context.textTheme.labelSmall,
            ),
          ),
        DionBadge(
          child: Icon(
            switch (entry.mediaType) {
              MediaType.audio => Icons.music_note,
              MediaType.video => Icons.videocam,
              MediaType.book => Icons.menu_book,
              MediaType.comic => Icons.image,
              MediaType.unknown => Icons.help,
            },
            size: 15,
          ),
        ),
      ],
      trailingBadges: [
        if (entry is EntrySaved)
          DionBadge(
            child: CountryFlag.fromLanguageCode(
              (entry as EntrySaved).language,
              height: 15,
              width: 15,
            ),
          ),
        DionBadge(
          child: DionImage(
            imageUrl: entry.extension.data.icon,
            width: 15,
            height: 15,
          ),
        ),
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
                  color: context.theme.colorScheme.primary,
                ),
                const Spacer(),
                if (entry.views != null)
                  Text(
                    NumberFormat.compact().format(entry.views),
                    style: context.textTheme.titleSmall
                        ?.copyWith(color: Colors.white),
                  ),
              ],
            ).paddingOnly(left: 5),
          TextScroll(
            entry.title,
            pauseBetween: 1.seconds,
            velocity: const Velocity(pixelsPerSecond: Offset(50, 0)),
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
