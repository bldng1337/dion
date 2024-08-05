import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fancy_shimmer_image/defaults.dart';
import 'package:fancy_shimmer_image/widgets/default_error_widget.dart';
import 'package:fancy_shimmer_image/widgets/image_shimmer_widget.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FancyShimmerImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final ShimmerDirection shimmerDirection;
  final Duration shimmerDuration;
  final BoxFit boxFit;
  final String? cacheKey;
  final Color? shimmerBaseColor;
  final Color? shimmerHighlightColor;
  final Color? shimmerBackColor;
  final Widget? errorWidget;
  final BoxDecoration? boxDecoration;
  final Color? color;
  final Alignment? alignment;
  final ImageWidgetBuilder? imageBuilder;
  final Map<String, String>? httpHeaders;

  const FancyShimmerImage({
    super.key,
    required this.imageUrl,
    this.boxFit = BoxFit.fill,
    this.httpHeaders,
    this.width = 300,
    this.height = 300,
    this.shimmerDirection = ShimmerDirection.ltr,
    this.shimmerDuration = const Duration(milliseconds: 1500),
    this.cacheKey,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.shimmerBackColor,
    this.errorWidget,
    this.boxDecoration,
    this.color,
    this.alignment,
    this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == 'https://0.0.0.0/') {
      return errorWidget ??
          Icon(
            Icons.image,
            size: min(width, height),
            color: Colors.grey,
          );
    }
    if (imageUrl.startsWith('file:')) {
      return Image.file(File(imageUrl.substring(7)));
    }
    return CachedNetworkImage(
      httpHeaders: httpHeaders,
      alignment: alignment ?? Alignment.center,
      color: color,
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      fit: boxFit,
      width: width,
      height: height,
      imageBuilder: imageBuilder,
      placeholder: (context, url) => ImageShimmerWidget(
        width: width,
        height: height,
        shimmerDirection: shimmerDirection,
        shimmerDuration: shimmerDuration,
        baseColor: shimmerBaseColor ?? defaultShimmerBaseColor,
        highlightColor: shimmerHighlightColor ?? defaultShimmerHighlightColor,
        backColor: shimmerBackColor ?? defaultShimmerBackColor,
        boxDecoration: boxDecoration,
      ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Icon(
            Icons.image,
            size: min(width, height),
            color: Colors.grey,
          ),
    );
  }
}
