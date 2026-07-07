import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/routes.dart';
import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/screenshot_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;
  late List<EntrySaved> savedEntries;

  setUpAll(() async {
    await bootstrapScreenshots();
    savedEntries = await seedMockLibrary();
    await seedMockActivity();
  });

  testWidgets('generate screenshots', (tester) async {
    for (final ff in formFactors) {
      await withFormFactor(tester, ff, () async {
        router = getRoutes(initialLocation: '/library');
        final app = MaterialApp.router(
          theme: getTheme(DionTheme.material.brightness),
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: screenshotBoundaryKey,
            child: child ?? const SizedBox.shrink(),
          ),
        );

        await tester.pumpWidget(app);
        await pumpStable(tester);
        await capture('library_${ff.fileSuffix}', pixelRatio: ff.devicePixelRatio);

        router.go('/activity');
        await pumpStable(tester);
        await capture('activity_${ff.fileSuffix}', pixelRatio: ff.devicePixelRatio);

        // Detail screen needs the Entry passed via `extra`.
        router.push('/detail', extra: [savedEntries.first]);
        await pumpStable(tester);
        await capture('entry_${ff.fileSuffix}', pixelRatio: ff.devicePixelRatio);
        router.pop();
        await pumpStable(tester);

        router.go('/settings');
        await pumpStable(tester);
        await capture('settings_${ff.fileSuffix}', pixelRatio: ff.devicePixelRatio);
      });
    }
  });
}
