import 'dart:math';
import 'dart:ui';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/share.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/buttons/clickable.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class DionNetworkImage extends ImageProvider<DionNetworkImage> {
  const DionNetworkImage(
    this.url, {
    this.width,
    this.height,
    this.httpHeaders,
    this.scale = 1.0,
  });

  final String url;

  final double? width;
  final double? height;
  final Map<String, String>? httpHeaders;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  Future<DionNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<DionNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    DionNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('URL: $url'),
      ],
    );
  }

  Future<Codec> _loadAsync(
    DionNetworkImage key, {
    required Future<Codec> Function(ImmutableBuffer buffer) decode,
  }) async {
    assert(key == this);
    if (url.startsWith('file://')) {
      final filePath = url.substring('file://'.length);
      return decode(await ImmutableBuffer.fromFilePath(filePath));
    }
    final cache = locate<CacheService>().imgcache;
    final fileinfo = await cache
        .getImageFile(
          url,
          headers: httpHeaders,
          maxHeight: height?.toInt(),
          maxWidth: width?.toInt(),
        )
        .where((e) => e is FileInfo)
        .last;
    final file = (fileinfo as FileInfo).file;
    final int lengthInBytes = await file.length();
    if (lengthInBytes == 0) {
      // The file may become available later.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }
    return decode(await ImmutableBuffer.fromFilePath(file.path));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is DionNetworkImage &&
        other.url == url &&
        other.scale == scale &&
        other.width == width &&
        other.height == height &&
        other.httpHeaders == httpHeaders;
  }

  @override
  int get hashCode => Object.hash(url, scale, width, height, httpHeaders);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'DionNetworkImage')}("$url", scale: ${scale.toStringAsFixed(1)})';
}

class DionImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final Map<String, String>? httpHeaders;
  final FilterQuality? filterQuality;
  final BoxFit? boxFit;
  final bool shouldAnimate;
  final bool hasPopup;
  final Function()? onTap;
  final BorderRadiusGeometry? borderRadius;
  // final String? cacheKey;
  final Widget? errorWidget;
  final Color? color;
  final Alignment? alignment;
  final Widget Function(BuildContext context)? loadingBuilder;
  const DionImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.boxFit,
    this.errorWidget,
    this.color,
    this.alignment,
    this.httpHeaders,
    this.filterQuality,
    this.loadingBuilder,
    this.shouldAnimate = true,
    this.borderRadius,
    this.hasPopup = false,
    this.onTap,
  }) : assert(
         (hasPopup ^ (onTap != null)) || (hasPopup == false && onTap == null),
       );

  @override
  _DionImageState createState() => _DionImageState();
}

class _DionImageState extends State<DionImage> with StateDisposeScopeMixin {
  Widget noImage(BuildContext context) {
    return FittedBox(
      fit: widget.boxFit ?? BoxFit.contain,
      child:
          widget.errorWidget ??
          Icon(Icons.image, size: min(widget.width ?? 24, widget.height ?? 24)),
    );
  }

  Widget getLoading(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    return Container(
      color: Colors.red,
      width: widget.width ?? widget.height ?? 24,
      height: widget.height ?? widget.width ?? 24,
    ).applyShimmer(highlightColor: widget.color);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.borderRadius == null) {
      return buildClickable(context);
    }
    return ClipRRect(
      borderRadius: widget.borderRadius!,
      child: buildClickable(context),
    );
  }

  Widget buildClickable(BuildContext context) {
    if (widget.onTap != null) {
      return Clickable(onTap: widget.onTap, child: buildImage(context));
    }
    if (widget.hasPopup) {
      return Clickable(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog.fullscreen(
              backgroundColor: Colors.transparent,
              child: GestureDetector(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    InteractiveViewer(
                      minScale: 0.1,
                      maxScale: 10,
                      child: buildImage(context, fullscreen: true),
                    ),
                    DionBadge(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DionIconbutton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close),
                          ),
                          DionIconbutton(
                            onPressed: () async {
                              final cache = locate<CacheService>().imgcache;
                              final fileinfo = await cache
                                  .getImageFile(
                                    widget.imageUrl!,
                                    headers: widget.httpHeaders,
                                  )
                                  .where((e) => e is FileInfo)
                                  .last;
                              final file = (fileinfo as FileInfo).file;
                              file.share();
                            },
                            icon: const Icon(Icons.share),
                          ),
                          DionIconbutton(
                            onPressed: () async {
                              await launchUrl(Uri.parse(widget.imageUrl!));
                            },
                            icon: const Icon(Icons.open_in_browser),
                          ),
                        ],
                      ),
                    ).paddingOnly(bottom: 5),
                  ],
                ).paddingAll(20),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
        child: buildImage(context),
      );
    }
    return buildImage(context);
  }

  Widget buildImage(BuildContext context, {bool fullscreen = false}) {
    final width = fullscreen ? context.width : widget.width;
    final height = fullscreen ? context.height : widget.height;
    final boxfit = fullscreen
        ? BoxFit.contain
        : widget.boxFit ?? BoxFit.contain;
    if (widget.imageUrl == null) {
      return SizedBox(width: width, height: height, child: noImage(context));
    }
    return Image(
      image: DionNetworkImage(
        widget.imageUrl!,
        width: width,
        height: height,
        httpHeaders: widget.httpHeaders,
      ),
      filterQuality: widget.filterQuality ?? FilterQuality.high,
      width: width,
      height: height,
      fit: boxfit,
      alignment: widget.alignment ?? Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        if (widget.errorWidget != null) {
          return widget.errorWidget!;
        }
        return SizedBox(
          child:ErrorDisplay(
            e: error,
            s: stackTrace,
            message: 'Failed to load image ${widget.imageUrl}',
          ),
          width: width,
          height: height,
        );
      },
      frameBuilder: (context, image, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return image;
        }
        final isLoaded = frame != null;
        final child = isLoaded ? image : getLoading(context);
        if (!widget.shouldAnimate) {
          return child;
        }
        return AnimatedSwitcher(
          duration: 400.milliseconds,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: child,
        );
      },
    );
  }
}
