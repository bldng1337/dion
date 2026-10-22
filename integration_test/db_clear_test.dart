import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/screenshot_harness.dart';

/// Regression test for the "Clear Database wipes paired devices" bug: clear()
/// deletes the data tables with plain DELETEs, which fire the CRDT sync
/// events and re-stamp every crdt row as a tombstone with a fresh HLC. Those
/// tombstones then won last-write-wins on every paired device and deleted
/// their libraries too. clear() must therefore wipe the crdt table as well,
/// after the data tables, in one transaction.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Clear Database wipes the synced tables and their crdt rows', (
    tester,
  ) async {
    await bootstrapScreenshots();
    final db = locate<Database>();

    final saved = await seedMockLibrary();
    for (final entry in saved) {
      await db.addEntry(entry);
    }
    expect(saved, isNotEmpty);
    expect(await db.getNumEntries(), saved.length);

    Future<int> crdtCount() async =>
        (await db.db.query('COUNT(SELECT * FROM crdt)')).first as int;
    expect(
      await crdtCount(),
      greaterThan(0),
      reason: 'saving entries must produce crdt rows to clear',
    );

    await db.clear();

    expect(await db.getNumEntries(), 0);
    expect(
      await crdtCount(),
      0,
      reason:
          'leftover crdt rows would sync back as fresh tombstones '
          'and delete everything on paired devices',
    );
  });
}
