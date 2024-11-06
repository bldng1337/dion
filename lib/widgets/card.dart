import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/stardisplay.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:go_router/go_router.dart';
import 'package:text_scroll/text_scroll.dart';

const double width = 300 / 1.5;
const double height = 600 / 2;

class Card extends StatelessWidget {
  final String? imageUrl;
  final List<Widget>? leadingBadges;
  final List<Widget>? trailingBadges;
  final Widget? bottom;
  final Function()? onTap;
  const Card({
    super.key,
    required this.imageUrl,
    this.leadingBadges,
    this.trailingBadges,
    this.bottom,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        if (imageUrl != null)
          DionImage(
            imageUrl: imageUrl,
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
    ).onTap(onTap ?? () {}).paddingAll(4);
  }
}

class EntryCard extends StatelessWidget {
  final Entry entry;
  const EntryCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      imageUrl: entry.cover,
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.rating != null)
            Stardisplay(
              fill: entry.rating!,
              width: 12,
              height: 12,
              color: context.theme.primaryColor,
            ).paddingOnly(left: 5),
          TextScroll(
            entry.title,
            style: context.textTheme.titleSmall?.copyWith(color: Colors.white),
          ).paddingOnly(bottom: 5, left: 5),
        ],
      ),
      onTap: () => GoRouter.of(context).push('/detail', extra: entry),
    );
  }
}
