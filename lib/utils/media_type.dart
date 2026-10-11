import 'package:dionysos/service/extension.dart';
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

  String get episodeName {
    switch (this) {
      case MediaType.audio:
        return 'Track';
      case MediaType.video:
        return 'Episode';
      case MediaType.comic:
        return 'Chapter';
      case MediaType.book:
        return 'Chapter';
      case MediaType.unknown:
        return 'Episode';
    }
  }

  /// Present-tense verb for history summaries, as used by the activity feed.
  String get activityVerb {
    switch (this) {
      case MediaType.audio:
        return 'Listened';
      case MediaType.video:
        return 'Watched';
      case MediaType.comic:
      case MediaType.book:
        return 'Read';
      case MediaType.unknown:
        return 'Consumed';
    }
  }

  String getEpisodeNames(int num) {
    if (num == 1) {
      return episodeName;
    }
    switch (this) {
      case MediaType.audio:
        return 'Tracks';
      case MediaType.video:
        return 'Episodes';
      case MediaType.comic:
        return 'Chapters';
      case MediaType.book:
        return 'Chapters';
      case MediaType.unknown:
        return 'Episodes';
    }
  }
}
