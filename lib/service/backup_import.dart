import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dionysos/data/activity/activity.dart';
import 'package:dionysos/data/activity/episode.dart';
import 'package:dionysos/data/backup/foreign.dart';
import 'package:dionysos/data/backup/lnreader.dart';
import 'package:dionysos/data/backup/tachiyomi.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/backup.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:uuid/uuid.dart';

/// Backup file extensions the restore picker offers.
const restorableBackupExtensions = [
  backupExtension,
  'tachibk',
  'gz',
  'proto',
  'zip',
];

class BackupImportResult {
  final String app;
  final int added;
  final int merged;
  final List<String> skipped;

  /// Extensions entries were bound to that are not installed yet.
  final Set<String> missingExtensions;

  const BackupImportResult({
    required this.app,
    this.added = 0,
    this.merged = 0,
    this.skipped = const [],
    this.missingExtensions = const {},
  });

  String get summary {
    final parts = [
      if (added > 0) '$added added',
      if (merged > 0) '$merged merged',
      if (skipped.isNotEmpty) '${skipped.length} skipped',
    ];
    final counts = parts.isEmpty ? 'nothing to import' : parts.join(', ');
    final missing = missingExtensions.isEmpty
        ? ''
        : '. Install to read: ${missingExtensions.join(', ')}';
    return 'Imported $app backup: $counts$missing';
  }
}

/// Restores a dion backup or imports one from Mihon, Aniyomi, Tsundoku or
/// LNReader, telling them apart by content rather than file name.
Future<BackupImportResult> importBackup(Uint8List bytes) async {
  if (isGzip(bytes)) return importForeignBackup(parseTachiyomiBackup(bytes));
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    // Neither gzip nor zip: an uncompressed protobuf backup.
    return importForeignBackup(parseTachiyomiBackup(bytes));
  }
  if (archive.findFile('dionmeta.json') != null) {
    await applyBackup(archive);
    return const BackupImportResult(app: 'dion');
  }
  if (isLnReaderBackup(archive)) {
    return importForeignBackup(parseLnReaderBackup(archive));
  }
  throw const FormatException('Not a recognised backup file');
}

Future<BackupImportResult> importForeignBackup(ForeignBackup backup) async {
  final db = locate<Database>();
  final resolver = _SourceResolver(locate<ExtensionService>());
  final categoriesByName = {
    for (final category in await db.getCategories()) category.name: category,
  };
  for (final category in backup.categories) {
    if (categoriesByName.containsKey(category.name)) continue;
    final created = Category.construct(category.name, categoriesByName.length);
    await db.updateCategory(created);
    categoriesByName[category.name] = created;
  }

  var added = 0;
  var merged = 0;
  final skipped = [...backup.skipped];
  final activities = <Activity>[];
  for (final foreign in backup.entries) {
    try {
      final binding = resolver.resolve(foreign.source);
      if (binding == null) {
        skipped.add(
          '${foreign.title}: ${resolver.describe(foreign.source)} '
          'is not installed',
        );
        continue;
      }
      final entry = _toEntry(foreign, binding, categoriesByName);
      final existing = await db.isSaved(entry);
      final target = existing == null ? entry : _merge(existing, entry);
      await db.updateEntry(target);
      if (existing == null) {
        added++;
      } else {
        merged++;
      }
      activities.addAll(_activities(foreign, target));
    } catch (e, stack) {
      logger.e(
        'Failed to import ${foreign.title} from ${backup.app}',
        error: e,
        stackTrace: stack,
      );
      skipped.add('${foreign.title}: $e');
    }
  }
  if (activities.isNotEmpty) await db.addActivities(activities);

  for (final reason in skipped) {
    logger.w('${backup.app} import skipped $reason');
  }
  return BackupImportResult(
    app: backup.app,
    added: added,
    merged: merged,
    skipped: skipped,
    missingExtensions: resolver.missing,
  );
}

/// The dion extension an entry belongs to, and the site its relative urls
/// resolve against when that extension is installed.
typedef _Binding = ({String extensionId, Uri? site});

class _SourceResolver {
  final ExtensionService _extensions;
  final missing = <String>{};

  _SourceResolver(this._extensions);

  /// Null when the entry cannot be bound without the extension installed.
  _Binding? resolve(ForeignSource source) {
    switch (source) {
      case TachiyomiSource(:final id, :final name):
        if (name != null && isTsundokuJsSource(id, name)) {
          // Tsundoku keeps no plugin id, so only an installed plugin can
          // tell which dion extension the entry belongs to.
          final plugin = _lnReaderExtensionNamed(lnReaderDisplayName(name));
          return plugin == null ? null : _bind(plugin.id, plugin);
        }
        return _bindById(mihonExtensionId(id), name ?? 'source $id');
      case LnReaderSource(:final pluginId):
        return _bindById(lnReaderExtensionId(pluginId), pluginId);
    }
  }

  String describe(ForeignSource source) => switch (source) {
    TachiyomiSource(:final id, :final name)
        when name != null && isTsundokuJsSource(id, name) =>
      'LNReader plugin ${lnReaderDisplayName(name)}',
    TachiyomiSource(:final id, :final name) => name ?? 'source $id',
    LnReaderSource(:final pluginId) => 'LNReader plugin $pluginId',
  };

  _Binding _bindById(String extensionId, String label) {
    final extension = _extensions.tryGetExtension(extensionId);
    if (extension == null) missing.add(label);
    return _bind(extensionId, extension);
  }

  _Binding _bind(String extensionId, Extension? extension) {
    final site = extension == null ? null : Uri.tryParse(extension.data.url);
    return (
      extensionId: extensionId,
      site: site == null || !site.hasScheme ? null : site,
    );
  }

  Extension? _lnReaderExtensionNamed(String name) {
    final wanted = name.toLowerCase();
    return _extensions
        .getExtensions(
          extfilter: (e) =>
              e.id.startsWith(_lnReaderPrefix) &&
              e.data.name.toLowerCase() == wanted,
        )
        .firstOrNull;
  }
}

rust.EntryDetailed _detailed(ForeignEntry foreign, _Binding binding) {
  String resolve(String url) {
    final site = binding.site;
    // Only the LNReader adapter exposes absolute urls; Mihon keeps the
    // source-relative one.
    if (site == null || !binding.extensionId.startsWith(_lnReaderPrefix)) {
      return url;
    }
    return Uri.tryParse(url)?.hasScheme ?? false
        ? url
        : site.resolve(url).toString();
  }

  final title = foreign.title.isEmpty ? foreign.url : foreign.title;
  return rust.EntryDetailed(
    id: rust.EntryId(uid: foreign.url),
    url: resolve(foreign.url),
    titles: [title, ...foreign.altTitles.where((t) => t != title)],
    author: foreign.authors.isEmpty ? null : foreign.authors,
    mediaType: foreign.mediaType,
    status: foreign.status,
    description: foreign.description ?? '',
    language: '',
    cover: _link(foreign.cover),
    poster: _link(foreign.poster),
    genres: foreign.genres.isEmpty ? null : foreign.genres,
    episodes: [
      for (final chapter in foreign.chapters)
        rust.Episode(
          id: rust.EpisodeId(uid: chapter.url),
          name: chapter.name,
          description: chapter.description,
          url: resolve(chapter.url),
          cover: _link(chapter.cover),
          timestamp: chapter.uploaded,
        ),
    ],
  );
}

rust.Link? _link(String? url) =>
    url == null || url.isEmpty ? null : rust.Link(url: url);

EntrySaved _toEntry(
  ForeignEntry foreign,
  _Binding binding,
  Map<String, Category> categoriesByName,
) {
  final detailed = _detailed(foreign, binding);
  return EntrySaved(
    entry: detailed,
    // Stands in for the source's own data until the first refresh.
    original: detailed,
    categories: [
      for (final name in foreign.categories.toSet())
        if (categoriesByName[name] case final category?) category,
    ],
    boundExtensionId: binding.extensionId,
    episode: 0,
    savedSettings: EntrySavedSettings.defaultSettings(),
    extensionSettings: {},
    note: foreign.note,
    episodedata: {
      for (final chapter in foreign.chapters)
        if (chapter.finished || chapter.bookmark || chapter.progress != null)
          chapter.url: EpisodeData(
            bookmark: chapter.bookmark,
            finished: chapter.finished,
            progress: chapter.progress,
          ),
    },
  )..updateReleasePrediction();
}

/// Keeps what dion already knows about an entry and only adds progress,
/// bookmarks and categories from the import.
EntrySaved _merge(EntrySaved existing, EntrySaved imported) {
  for (final MapEntry(:key, :value) in imported.episodedata.entries) {
    final data = existing.getEpisodeDataById(key);
    data.finished |= value.finished;
    data.bookmark |= value.bookmark;
    if (!data.finished) data.progress ??= value.progress;
  }
  final known = {for (final category in existing.categories) category.id};
  existing.categories = [
    ...existing.categories,
    ...imported.categories.where((category) => !known.contains(category.id)),
  ];
  existing.note ??= imported.note;
  return existing;
}

List<Activity> _activities(ForeignEntry foreign, EntrySaved entry) {
  final indexByUid = {
    for (final (index, episode) in entry.episodes.indexed)
      episode.id.uid: index,
  };
  return [
    for (final history in foreign.history)
      if (indexByUid[history.chapterUrl] case final index?)
        EpisodeActivity(
          fromepisode: index,
          toepisode: index,
          entry: entry,
          extensionid: entry.boundExtensionId,
          duration: history.duration,
          time: history.time,
          // Deterministic, so importing the same backup twice adds no
          // duplicate history.
          id: const Uuid().v5(
            Namespace.url.value,
            'import:${entry.boundExtensionId}:${entry.id.uid}:'
            '${history.chapterUrl}:${history.time.millisecondsSinceEpoch}',
          ),
        ),
  ];
}

String mihonExtensionId(int sourceId) => 'mihon:$sourceId';

const _lnReaderPrefix = 'lnreader.';

/// Mirrors `extension_id` in the runtime's LNReader adapter.
String lnReaderExtensionId(String pluginId) {
  var id = pluginId.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  while (id.contains('..')) {
    id = id.replaceAll('..', '_');
  }
  return '$_lnReaderPrefix$id';
}

/// Mirrors `display_name` in the runtime's LNReader adapter, which drops
/// multisrc tags such as `[madara]`.
String lnReaderDisplayName(String name) {
  final start = name.indexOf('[');
  final end = name.lastIndexOf(']');
  if (start == -1 || end == -1 || start >= end) return name.trim();
  return '${name.substring(0, start)}${name.substring(end + 1)}'.trim();
}

/// The language names LNReader plugin indexes use (lnreader-plugins
/// `scripts/languages.js`), which Tsundoku hashes into its JS source ids.
const _lnReaderLanguages = [
  'العربية',
  '‎العربية',
  'বাংলা',
  '中文, 汉语, 漢語',
  'English',
  'Français',
  'Bahasa Indonesia',
  '日本語',
  '조선말, 한국어',
  'Polski',
  'Português',
  'Русский',
  'Español',
  'ไทย',
  'Türkçe',
  'Українська',
  'Tiếng Việt',
  'Multi',
];

/// Whether a Tsundoku source id belongs to one of its LNReader JS plugins,
/// whose ids are `"${name.lowercase()}/$lang/js".hashCode() and Long.MAX_VALUE`.
bool isTsundokuJsSource(int sourceId, String name) {
  final lower = name.toLowerCase();
  return _lnReaderLanguages.any(
    (lang) => _javaStringHash('$lower/$lang/js') == sourceId,
  );
}

int _javaStringHash(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (31 * hash + unit).toSigned(32);
  }
  // Kotlin widens the Int with sign extension before masking the sign bit.
  return hash & 0x7fffffffffffffff;
}
