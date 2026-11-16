import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/bench.dart';
import 'utils/bench_seed.dart';
import 'utils/screenshot_harness.dart';

/// Engine-side query variants: current statement vs. candidate rewrites,
/// with result equality checked so a faster variant cannot be a wrong one.
const _entryCount = int.fromEnvironment('BENCH_ENTRIES', defaultValue: 1000);
const _iters = int.fromEnvironment('BENCH_ITERS', defaultValue: 15);

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final samples = <BenchSample>[];

  testWidgets('query variants', (tester) async {
    await bootstrapScreenshots();
    final db = locate<Database>();
    await seedBenchLibrary(db, entryCount: _entryCount);
    final cat = (await db.getCategories()).first;

    Future<dynamic> q(String sql, [Map<String, dynamic>? vars]) async =>
        (await db.db.query(sql, vars: vars))[0];
    Future<void> run(String name, Future<void> Function() body) async =>
        samples.add(await bench(name, _iters, body));
    Future<void> explain(
      String name,
      String sql, [
      Map<String, dynamic>? v,
    ]) async => logger.i('EXPLAIN $name:\n${await q('$sql EXPLAIN', v)}');

    // --- default library order ---
    const orderById = 'SELECT * FROM entry ORDER BY id LIMIT 25';
    const noOrder = 'SELECT * FROM entry LIMIT 25';
    await explain('order_by_id', orderById);
    await explain('no_order', noOrder);
    final a = (await q(orderById) as List).map((r) => r['id']).toList();
    final b = (await q(noOrder) as List).map((r) => r['id']).toList();
    logger.i(
      'no-ORDER table scan in id order: ${a.toString() == b.toString()}',
    );
    await run('page25_order_by_id', () => q(orderById));
    await run('page25_no_order', () => q(noOrder));
    await run(
      'page25_cat_order_by_id',
      () => q(
        'SELECT * FROM entry WHERE categories CONTAINS \$c ORDER BY id LIMIT 25',
        {'c': cat.id},
      ),
    );
    await run(
      'page25_cat_no_order',
      () => q('SELECT * FROM entry WHERE categories CONTAINS \$c LIMIT 25', {
        'c': cat.id,
      }),
    );
    await run(
      'page25_order_by_id_fetch',
      () => q('$orderById FETCH categories'),
    );

    // --- counts ---
    Future<int> count(String where, [Map<String, dynamic>? v]) async {
      final rows =
          await q('SELECT count() FROM entry $where GROUP ALL', v) as List;
      return rows.isEmpty ? 0 : rows.first['count'] as int;
    }

    final uncats = {
      'count_eq0': 'WHERE count(categories) = 0',
      'is_empty': 'WHERE array::is_empty(categories ?? [])',
      'eq_empty': 'WHERE categories = []',
      'len_eq0': 'WHERE array::len(categories) = 0',
    };
    for (final MapEntry(:key, :value) in uncats.entries) {
      logger.i('uncategorized $key = ${await count(value)}');
      await run('count_uncat_$key', () => count(value));
    }
    await run('count_all', () => count(''));
    await run(
      'count_cat',
      () => count('WHERE categories CONTAINS \$c', {'c': cat.id}),
    );
    await explain('count_all', 'SELECT count() FROM entry GROUP ALL');
    await explain(
      'count_cat',
      'SELECT count() FROM entry WHERE categories CONTAINS \$c GROUP ALL',
      {'c': cat.id},
    );
    await explain(
      'count_uncat',
      'SELECT count() FROM entry WHERE count(categories) = 0 GROUP ALL',
    );
    const grouped =
        'SELECT categories, count() AS n FROM entry GROUP BY categories';
    logger.i('grouped counts: ${await q(grouped)}');
    await run('count_grouped_all_tabs', () => q(grouped));

    // --- whole-library scans ---
    await run('scan_hydrated_offset', () async {
      for (var p = 0; ; p++) {
        if ((await db.getEntries(p, 100).toList()).isEmpty) break;
      }
    });
    await run('scan_raw_offset', () async {
      for (var p = 0; ; p++) {
        final rows = await q(
          'SELECT * FROM entry ORDER BY id LIMIT 100 START \$o FETCH categories',
          {'o': p * 100},
        ) as List;
        if (rows.isEmpty) break;
      }
    });
    await run('scan_raw_keyset', () async {
      Object? last;
      while (true) {
        final rows = await q(
          'SELECT * FROM entry ${last == null ? '' : 'WHERE id > \$last'} '
          'ORDER BY id LIMIT 100 FETCH categories',
          {'last': last},
        ) as List;
        if (rows.isEmpty) break;
        last = rows.last['id'];
      }
    });
    await run(
      'scan_proj_ids',
      () => q('SELECT VALUE [extensionid, entry.id.uid] FROM entry'),
    );
    const imageProj =
        'SELECT VALUE [id, entry.cover.url, entry.poster.url, '
        'array::flatten(object::values(episodedata ?? {}).images).url] FROM entry';
    logger.i('image proj sample: ${await q('$imageProj LIMIT 2')}');
    await run('scan_proj_images', () => q(imageProj));

    // --- hydration only ---
    final rows = [
      for (final r
          in await q('SELECT * FROM entry LIMIT 100 FETCH categories') as List)
        Map<String, dynamic>.from(r as Map),
    ];
    await run('hydrate100_fromJson', () async {
      for (final r in rows) {
        await EntrySaved.fromJson(r);
      }
    });
    final hydrated = await Future.wait(rows.map(EntrySaved.fromJson));
    await run('hydrate100_toJson', () async {
      for (final e in hydrated) {
        e.toJson();
      }
    });
  });

  tearDownAll(
    () => logger.i('\nBENCH_ENTRIES=$_entryCount${formatBenchTable(samples)}'),
  );
}
