import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

@immutable
class DionNetworkImage extends ImageProvider<DionNetworkImage> {
  const DionNetworkImage(this.url,
      {this.width, this.height, this.httpHeaders, this.scale = 1.0});

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

  // @override
  // ImageStreamCompleter loadBuffer(
  //     DionNetworkImage key, DecoderBufferCallback decode) {
  //   return MultiFrameImageStreamCompleter(
  //     codec: _loadAsync(key, decode: decode),
  //     scale: key.scale,
  //     debugLabel: key.url,
  //     informationCollector: () => <DiagnosticsNode>[
  //       ErrorDescription('URL: $url'),
  //     ],
  //   );
  // }

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
    // await Future.delayed(const Duration(seconds: 3));
    final file = (fileinfo as FileInfo).file;
    final int lengthInBytes = await file.length();
    if (lengthInBytes == 0) {
      // The file may become available later.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }
    return (file.runtimeType == File)
        ? decode(await ImmutableBuffer.fromFilePath(file.path))
        : decode(await ImmutableBuffer.fromUint8List(await file.readAsBytes()));
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
  // final String? cacheKey;
  final Widget? errorWidget;
  final Color? color;
  final Alignment? alignment;
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
  });

  @override
  _DionImageState createState() => _DionImageState();
}

class _DionImageState extends State<DionImage> with StateDisposeScopeMixin {
  int count = 0;
  int total = 0;
  File? image;
  bool error = false;
  @override
  void initState() {
    // if (widget.imageUrl == null) {
    //   error = true;
    //   return;
    // }

    // final cache = locate<CacheService>().imgcache;
    // cache
    //     .getImageFile(
    //   widget.imageUrl!,
    //   headers: widget.httpHeaders,
    //   maxHeight: widget.height?.toInt(),
    //   maxWidth: widget.width?.toInt(),
    //   withProgress: true,
    // )
    //     .listen(
    //   (update) {
    //     switch (update) {
    //       case final FileInfo finfo:
    //         if (mounted) {
    //           setState(() {
    //             image = finfo.file;
    //           });
    //         }
    //       case final DownloadProgress progress:
    //         count = progress.downloaded;
    //         total = progress.totalSize ?? 0;
    //     }
    //   },
    //   onError: (e) {
    //     if (mounted) {
    //       setState(() {
    //         // logger.e('Error downloading Image', error: e);
    //         error = true;
    //       });
    //     }
    //   },
    // );
    super.initState();
  }

  Widget noImage(BuildContext context) {
    return FittedBox(
      fit: widget.boxFit ?? BoxFit.contain,
      child: widget.errorWidget ??
          Icon(Icons.image, size: min(widget.width ?? 24, widget.height ?? 24)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: noImage(context),
      );
    }
    
    return Image(
      image: DionNetworkImage(
        widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        httpHeaders: widget.httpHeaders,
      ),
      filterQuality: widget.filterQuality ?? FilterQuality.medium,
      width: widget.width,
      height: widget.height,
      fit: widget.boxFit ?? BoxFit.contain,
      alignment: widget.alignment ?? Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        logger.e(
          'Error loading image ${widget.imageUrl}',
          error: error,
          stackTrace: stackTrace,
        );
        return ErrorDisplay(
          e: error,
          s: stackTrace,
          message: 'Failed to load image ${widget.imageUrl}',
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return child.applyShimmer();
      },
    );
    // if (error) {
    //   return FittedBox(
    //     fit: widget.boxFit ?? BoxFit.contain,
    //     child: widget.errorWidget ??
    //         Icon(Icons.image,
    //             size: min(widget.width ?? 24, widget.height ?? 24)),
    //   );
    // }
    // if (image != null) {
    //   return m.Image.file(
    //     image!,
    //     filterQuality: widget.filterQuality ?? FilterQuality.medium,
    //     width: widget.width,
    //     height: widget.height,
    //     fit: widget.boxFit ?? BoxFit.contain,
    //     alignment: widget.alignment ?? Alignment.center,
    //     errorBuilder: (context, error, stackTrace) {
    //       logger.e(
    //         'Error loading image ${widget.imageUrl}',
    //         error: error,
    //         stackTrace: stackTrace,
    //       );
    //       return widget.errorWidget ??
    //           Icon(
    //             Icons.image,
    //             size: min(widget.width ?? 24, widget.height ?? 24),
    //           );
    //     },
    //   );
    // }
    // final progress = (count.toDouble()) / (total.toDouble() + 0.00001);
    // return FittedBox(
    //   fit: widget.boxFit ?? BoxFit.contain,
    //   child: SizedBox(
    //     width: widget.width,
    //     height: widget.height,
    //     child: Stack(
    //       children: [
    //         SizedBox(width: widget.width, height: widget.height)
    //             .applyShimmer(highlightColor: widget.color),
    //         if (progress >= 0 && progress <= 1)
    //           Center(
    //             child: CircularProgressIndicator(
    //               value: progress,
    //             ),
    //           ),
    //       ],
    //     ),
    //   ),
    // );
  }
}
