import 'dart:io';
import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class DionImage extends StatefulWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit? boxFit;
  // final String? cacheKey;
  final Widget? errorWidget;
  final Color? color;
  final Alignment? alignment;
  final Map<String, String>? httpHeaders;
  const DionImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.boxFit,
    this.errorWidget,
    this.color,
    this.alignment,
    this.httpHeaders,
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
    if (widget.imageUrl == null) {
      error = true;
      return;
    }
    final cache = locate<CacheService>().imgcache;
    cache
        .getImageFile(
      widget.imageUrl!,
      headers: widget.httpHeaders,
      maxHeight: widget.height.toInt(),
      maxWidth: widget.width.toInt(),
      withProgress: true,
    )
        .listen(
      (update) {
        switch (update) {
          case final FileInfo finfo:
            if (mounted) {
              setState(() {
                image = finfo.file;
              });
            }
          case final DownloadProgress progress:
            count = progress.downloaded;
            total = progress.totalSize ?? 0;
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            // logger.e('Error downloading Image', error: e);
            error = true;
          });
        }
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (error) {
      return widget.errorWidget ??
          Icon(Icons.image, size: min(widget.width, widget.height));
    }
    if (image != null) {
      return m.Image.file(
        image!,
        width: widget.width,
        height: widget.height,
        fit: widget.boxFit,
        alignment: widget.alignment ?? Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          logger.e(
            'Error loading image ${widget.imageUrl}',
            error: error,
            stackTrace: stackTrace,
          );
          return widget.errorWidget ??
              Icon(Icons.image, size: min(widget.width, widget.height));
        },
      );
    }
    return SizedBox(width: widget.width, height: widget.height)
        .applyShimmer(highlightColor: widget.color);
  }
}
