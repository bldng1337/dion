import 'package:rdion_runtime/rdion_runtime.dart' show MediaType, ReleaseStatus;

/// A library read from another app's backup, before it is mapped onto the
/// extensions installed in dion.
class ForeignBackup {
  final String app;
  final List<ForeignCategory> categories;
  final List<ForeignEntry> entries;

  /// Entries the parser dropped, with the reason, e.g. local files.
  final List<String> skipped;

  const ForeignBackup({
    required this.app,
    required this.categories,
    required this.entries,
    this.skipped = const [],
  });
}

class ForeignCategory {
  final String name;
  final int order;

  const ForeignCategory(this.name, this.order);
}

/// Where an entry came from in the other app.
sealed class ForeignSource {
  const ForeignSource();
}

/// A Tachiyomi-family source (Mihon, Aniyomi, Tsundoku), identified by the
/// source id those apps derive from the source's name, language and version.
class TachiyomiSource extends ForeignSource {
  final int id;
  final String? name;

  const TachiyomiSource(this.id, this.name);
}

/// An LNReader plugin, identified by the plugin's own id.
class LnReaderSource extends ForeignSource {
  final String pluginId;

  const LnReaderSource(this.pluginId);
}

class ForeignEntry {
  final ForeignSource source;

  /// The source-relative url, which the dion adapters use as the entry uid.
  final String url;
  final String title;
  final List<String> altTitles;
  final MediaType mediaType;
  final List<String> authors;
  final String? description;
  final List<String> genres;
  final ReleaseStatus status;
  final String? cover;
  final String? poster;
  final String? note;

  /// Oldest first, as the dion adapters list episodes.
  final List<ForeignChapter> chapters;
  final List<String> categories;
  final List<ForeignHistory> history;

  const ForeignEntry({
    required this.source,
    required this.url,
    required this.title,
    this.altTitles = const [],
    required this.mediaType,
    this.authors = const [],
    this.description,
    this.genres = const [],
    this.status = ReleaseStatus.unknown,
    this.cover,
    this.poster,
    this.note,
    required this.chapters,
    this.categories = const [],
    this.history = const [],
  });
}

class ForeignChapter {
  /// The source-relative url, which the dion adapters use as the episode uid.
  final String url;
  final String name;
  final String? description;
  final String? cover;
  final DateTime? uploaded;
  final bool finished;
  final bool bookmark;

  /// Already in dion's per-reader progress encoding.
  final String? progress;

  const ForeignChapter({
    required this.url,
    required this.name,
    this.description,
    this.cover,
    this.uploaded,
    this.finished = false,
    this.bookmark = false,
    this.progress,
  });
}

class ForeignHistory {
  final String chapterUrl;
  final DateTime time;
  final Duration duration;

  const ForeignHistory(this.chapterUrl, this.time, this.duration);
}

DateTime? dateFromEpochMillis(int? millis) => millis == null || millis <= 0
    ? null
    : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
