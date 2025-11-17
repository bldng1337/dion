import 'package:dionysos/service/source_extension.dart';
import 'package:flutter/material.dart';

extension MediaTypeExtension on MediaType {
  IconData get icon {
    switch (this) {
      case MediaType.audio:
        return Icons.headset;
      case MediaType.video:
        return Icons.videocam;
      case MediaType.comic:
        return Icons.image_rounded;
      case MediaType.book:
        return Icons.menu_book;
      case MediaType.unknown:
        return Icons.help_outline;
    }
  }
}
