import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dionysos/data/category.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/settings/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metis/metis.dart' as metis;

import 'utils/mock.dart';
import 'utils/screenshot_harness.dart';

/// Opens an in-memory database on the production initialization path.
/// Connects directly instead of going through [Database.init] so the FRB
/// runtime initialized once in setUpAll is not re-initialized.
Future<Database> _openMemoryDb() async {
  final db = Database();
  await db.initDB(await metis.AdapterSurrealDB.connect('memory://'));
  register<Database>(db);
  return db;
}

/// Backup regression tests: a backup must carry the whole library, not just
/// entry rows — categories (definitions and entry assignments), extension
/// metadata and settings are user data too, and all text must survive the
/// UTF-8 zip round trip unchanged.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(bootstrapScreenshots);

  const categoryName = 'Reading – 中文 ✓';
  const quoteText = '«Vécu» — naïve façade 🌟';

  testWidgets('Backup round-trips onto a fresh database', (tester) async {
    final db = await _openMemoryDb();

    final saved = await seedMockLibrary();
    for (final entry in saved) {
      await db.addEntry(entry);
    }
    expect(saved, isNotEmpty);

    final category = Category.construct(categoryName, 0);
    await db.updateCategory(category);
    saved.first.categories = [category];
    saved.first
        .getEpisodeData(0)
        .quotes
        .add(SavedQuote(text: quoteText, savedAt: DateTime.now()));
    await db.updateEntry(saved.first);

    await db.setExtensionMetaData(
      const ExtensionMetaData(
        MockExtension.mockId,
        true,
        autoAddRules: ['rule:*'],
      ),
    );

    // Referencing a field builds the lazy settings tree and registers every
    // preference-backed Setting in preferenceCollection.
    final boolSetting = settings.background.unmeteredOnly;
    boolSetting.value = !boolSetting.value;
    final expectedSettingValue = boolSetting.value;

    final archive = await createBackup();
    final decoded = ZipDecoder().decodeBytes(ZipEncoder().encodeBytes(archive));

    // Simulate a fresh device: a new in-memory database with no categories,
    // entries or extension metadata.
    final fresh = await _openMemoryDb();

    // Stray from the backed-up value so the restore has to bring it back.
    boolSetting.value = !expectedSettingValue;

    await applyBackup(decoded);

    expect(await fresh.getNumEntries(), saved.length);

    final restoredCategories = await fresh.getCategories();
    expect(restoredCategories.map((c) => c.name), [categoryName]);
    expect(restoredCategories.single.index, 0);

    final restoredEntry = await fresh.getSavedById(saved.first.id);
    expect(restoredEntry, isNotNull);
    expect(restoredEntry!.categories.map((c) => c.name), [categoryName]);
    expect(
      restoredEntry.getEpisodeData(0).quotes.single.text,
      quoteText,
      reason: 'non-ASCII text must survive the backup round trip',
    );

    final extensionMetadata = await fresh.getExtensionsMetadata();
    expect(extensionMetadata.single.enabled, isTrue);
    expect(extensionMetadata.single.autoAddRules, ['rule:*']);

    expect(boolSetting.value, expectedSettingValue);
  });

  testWidgets('V2 backups recreate categories referenced by name', (
    tester,
  ) async {
    final db = await _openMemoryDb();

    final saved = await seedMockLibrary();
    expect(saved, isNotEmpty);

    // V2 format: entries carry category names, no categorydata.json exists.
    final entryJson = saved.first.toJson();
    entryJson['categories'] = [categoryName];
    final v2 = Archive()
      ..addFile(
        ArchiveFile.string(
          'dionmeta.json',
          json.encode({
            'version': 2,
            'content': ['entries', 'activities'],
          }),
        ),
      )
      ..addFile(ArchiveFile.string('entrydata.json', json.encode([entryJson])))
      ..addFile(ArchiveFile.string('activitydata.json', json.encode([])));

    await applyBackup(v2);

    final restoredCategories = await db.getCategories();
    expect(restoredCategories.map((c) => c.name), [categoryName]);
    final restoredEntry = await db.getSavedById(saved.first.id);
    expect(restoredEntry, isNotNull);
    expect(restoredEntry!.categories.map((c) => c.name), [categoryName]);
  });
}
