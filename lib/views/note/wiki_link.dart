import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/wiki_markdown.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Resolves a `[[...]]` note link against the library and navigates to the
/// target entry or chapter. Unresolvable targets surface a snackbar instead
/// of failing silently (Obsidian-style unresolved links).
Future<void> openWikiLink(
  BuildContext context,
  EntrySaved currentEntry,
  String target,
) async {
  final parsed = parseWikiTarget(target);
  if (parsed == null) return;
  final (:entryTitle, :chapter) = parsed;
  try {
    final entry = entryTitle == null
        ? currentEntry
        : await findEntryByTitle(entryTitle);
    if (!context.mounted) return;
    if (entry == null) {
      _showUnresolved(context, target);
      return;
    }
    if (chapter == null) {
      context.push('/detail', extra: [entry]);
      return;
    }
    final index = findChapterIndex(entry, chapter);
    if (index == null) {
      _showUnresolved(context, target);
      return;
    }
    EpisodePath(entry, index).go(context);
  } catch (e, stack) {
    logger.e('Error resolving note link $target', error: e, stackTrace: stack);
    if (context.mounted) {
      _showUnresolved(context, target);
    }
  }
}

/// Finds a library entry by title: exact (case-insensitive) match preferred,
/// first title-contains match as fallback.
Future<EntrySaved?> findEntryByTitle(String title) async {
  final lower = title.toLowerCase();
  EntrySaved? containsMatch;
  await for (final entry in locate<Database>().searchEntries(title, 0, 50)) {
    final titles = entry.titles ?? const <String>[];
    if (titles.any((t) => t.trim().toLowerCase() == lower)) {
      return entry;
    }
    containsMatch ??= titles.any((t) => t.trim().toLowerCase().contains(lower))
        ? entry
        : null;
  }
  return containsMatch;
}

/// Finds an episode by chapter name: exact, then case-insensitive exact, then
/// contains.
int? findChapterIndex(EntrySaved entry, String chapter) {
  final episodes = entry.episodes;
  final lower = chapter.trim().toLowerCase();
  for (var i = 0; i < episodes.length; i++) {
    if (episodes[i].name == chapter) return i;
  }
  for (var i = 0; i < episodes.length; i++) {
    if (episodes[i].name.trim().toLowerCase() == lower) return i;
  }
  for (var i = 0; i < episodes.length; i++) {
    if (episodes[i].name.trim().toLowerCase().contains(lower)) return i;
  }
  return null;
}

void _showUnresolved(BuildContext context, String target) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text("Couldn't find '$target' in your library"),
    ),
  );
}
