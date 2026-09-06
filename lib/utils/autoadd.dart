import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

const autoAddTokenAll = '*';
const _mediaTypePrefix = 'mediaType:';
const _extensionPrefix = 'ext:';

String autoAddTokenForMediaType(rust.MediaType type) =>
    '$_mediaTypePrefix${type.name}';

String autoAddTokenForExtension(Extension extension) =>
    '$_extensionPrefix${extension.id}';

bool autoAddRulesMatch(
  List<String> rules,
  String boundExtensionId,
  rust.MediaType mediaType,
) {
  for (final rule in rules) {
    if (rule == autoAddTokenAll) return true;
    if (rule.startsWith(_mediaTypePrefix) &&
        rule.substring(_mediaTypePrefix.length) == mediaType.name) {
      return true;
    }
    if (rule.startsWith(_extensionPrefix) &&
        rule.substring(_extensionPrefix.length) == boundExtensionId) {
      return true;
    }
  }
  return false;
}

List<Extension> autoAddCandidatesFor(EntryDetailed entry) {
  final attached = entry is EntrySaved
      ? entry.entryExtensions.map((e) => e.extensionId).toSet()
      : const <String>{};
  return locate<ExtensionService>()
      .getExtensions()
      .where(
        (ext) =>
            ext.isenabled &&
            !attached.contains(ext.id) &&
            ext.getExtensionTypeOrNull<rust.ExtensionType_EntryProcessor>() !=
                null &&
            autoAddRulesMatch(
              ext.meta.autoAddRules,
              entry.boundExtensionId,
              entry.mediaType,
            ),
      )
      .toList();
}

Future<void> attachAutoAddExtensions(EntrySaved entry) async {
  for (final ext in autoAddCandidatesFor(entry)) {
    entry.entryExtensions = [
      ...entry.entryExtensions,
      EntryExtension(extensionId: ext.id, extensionSettings: {}),
    ];
    try {
      await entry.extension?.refreshEntryExtension(entry, ext);
    } catch (e, stack) {
      logger.w(
        'Failed to refresh auto-added entry extension ${ext.id} on ${entry.id}',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

Future<List<EntrySaved>> _entriesWhere(
  bool Function(EntrySaved entry) test,
) async {
  final db = locate<Database>();
  final result = <EntrySaved>[];
  var page = 0;
  while (true) {
    var any = false;
    await for (final entry in db.getEntries(page, 100)) {
      any = true;
      if (test(entry)) result.add(entry);
    }
    if (!any) break;
    page++;
  }
  return result;
}

Future<List<EntrySaved>> newlyMatchingEntries(
  Extension extension,
  List<String> oldRules,
) {
  final newRules = extension.meta.autoAddRules;
  return _entriesWhere(
    (entry) =>
        !entry.entryExtensions.any((e) => e.extensionId == extension.id) &&
        autoAddRulesMatch(
          newRules,
          entry.boundExtensionId,
          entry.mediaType,
        ) &&
        !autoAddRulesMatch(
          oldRules,
          entry.boundExtensionId,
          entry.mediaType,
        ),
  );
}

Future<int> backfillAutoAdd(Extension extension) async {
  final targets = await _entriesWhere(
    (entry) =>
        !entry.entryExtensions.any((e) => e.extensionId == extension.id) &&
        autoAddRulesMatch(
          extension.meta.autoAddRules,
          entry.boundExtensionId,
          entry.mediaType,
        ),
  );
  for (final entry in targets) {
    entry.entryExtensions = [
      ...entry.entryExtensions,
      EntryExtension(extensionId: extension.id, extensionSettings: {}),
    ];
    try {
      await entry.extension?.refreshEntryExtension(entry, extension);
    } catch (e, stack) {
      logger.w(
        'Failed to refresh backfilled entry extension ${extension.id} on ${entry.id}',
        error: e,
        stackTrace: stack,
      );
    }
    await entry.save();
  }
  return targets.length;
}
