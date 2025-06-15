import 'package:dionysos/service/source_extension.dart';
import 'package:flutter/material.dart';

extension MediaTypeExtension on MediaType {
  IconData get icon {
    switch (this) {
      case MediaType.audio:
        return Icons.audio_file;
      case MediaType.video:
        return Icons.video_file;
      case MediaType.comic:
        return Icons.image_rounded;
      case MediaType.book:
        return Icons.book;
      case MediaType.unknown:
        return Icons.help_outline;
    }
  }
}
