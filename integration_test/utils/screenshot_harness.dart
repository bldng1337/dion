import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:dionysos/data/activity/fake_activity.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/cache.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/service/downloads.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/service/network.dart';
import 'package:dionysos/service/preference.dart';
import 'package:dionysos/service/task.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inline_result/inline_result.dart';
import 'package:path/path.dart' as p;

import 'mock.dart';

/// Output directory for generated screenshots.
final Directory screenshotsDir = Directory(
  p.join(Directory.current.path, 'docs', 'screenshots'),
);

/// Key of the [RepaintBoundary] the test wraps the app in; [capture] looks it
/// up via this key to rasterize the current frame in-process.
final GlobalKey screenshotBoundaryKey = GlobalKey();

/// Form factors captured by the harness. [width] relative to the
/// `awesome_extensions` `showNavbar` breakpoint (width > 800) decides whether
/// the app renders the desktop NavigationRail or the mobile bottom bar.
class FormFactor {
  final String name;
  final double width;
  final double height;
  final double devicePixelRatio;
  const FormFactor({
    required this.name,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  String get fileSuffix => name;
}

const desktopFormFactor = FormFactor(
  name: 'desktop',
  width: 1440,
  height: 900,
  devicePixelRatio: 1.0,
);

const mobileFormFactor = FormFactor(
  name: 'mobile',
  width: 390,
  height: 844,
  devicePixelRatio: 2.625,
);

const formFactors = [desktopFormFactor, mobileFormFactor];

/// Bootstraps the minimal real service set needed to render the Activity,
/// Detail, Library and Settings screens, all isolated to an in-memory database
/// and a temporary directory so the user's real data is never touched.
///
/// Because the real `dion`/`mihon` extension adapters find no installed
/// extensions in the temp directory, the only extension that registers is the
/// `kDebugMode`-gated [MockExtension]. Every entry surfaced by the harness is
/// therefore a mock-extension entry.
Future<void> bootstrapScreenshots() async {
  // Temp DirectoryProvider: real adapters scan an empty extension dir, so they
  // load nothing and the debug mock is the sole registered extension.
  final tempBase = await Directory.systemTemp.createTemp('dion_screenshots_');
  register<DirectoryProvider>(
    DirectoryProvider(
      basepath: tempBase,
      extensionpath: await tempBase.sub('extension').create(recursive: true),
      databasepath: await tempBase.sub('database').create(recursive: true),
      temppath: await tempBase.sub('temp').create(recursive: true),
      downloadspath: await tempBase.sub('downloads').create(recursive: true),
    ),
  );

  // In-memory SurrealDB via the real (Rust-backed) adapter — no disk state.
  final db = Database();
  await db.init(inMemory: true);
  register<Database>(db);

  await TaskManager.ensureInitialized();
  await PreferenceService.ensureInitialized();
  // Real ExtensionService: registers the mock under kDebugMode, then reloads
  // the (empty) real adapters.
  await ExtensionService.ensureInitialized();

  // DionNetworkImage resolves covers/posters through CacheService, which in
  // turn needs NetworkService (an Rhttp client). On the desktop runner these
  // init normally and network covers load from placehold.co.
  await NetworkService.ensureInitialized();
  await CacheService.ensureInitialized();

  // EpisodeTile subscribes to a DownloadService status stream per episode, so
  // the real service is required (the mocktail mock returns null and throws).
  await DownloadService.ensureInitialized();
}

/// Saves every mock-extension entry to the in-memory library so the Library
/// and Detail screens have deterministic content to render.
///
/// Returns the saved entries (the first one is used for the detail shot).
Future<List<EntrySaved>> seedMockLibrary() async {
  final ext = locate<ExtensionService>()
      .getExtensions()
      .firstWhere((e) => e.id == MockExtension.mockId);

  // Pull the 12 placeholder entries through the mock's browse() stream.
  final controller = DataSourceController<Entry>([ext.browse()]);
  controller.requestMore();
  // Give the single-page async source a chance to emit.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  final entries = controller.items
      .map((r) => r.fold(onSuccess: (e) => e, onFailure: (_, _) => null))
      .whereType<Entry>()
      .toList();
  controller.dispose();

  final saved = <EntrySaved>[];
  for (final entry in entries) {
    final detailed = await entry.toDetailed();
    saved.add(await detailed.toSaved());
  }
  return saved;
}

/// Generates deterministic fake activity over the past year for the seeded
/// library so the Activity heatmap, treemap and feed render realistically.
Future<void> seedMockActivity({int seed = 1337}) async {
  await generateFakeActivity(days: 360, random: Random(seed));
}

/// Pumps the UI until it settles, bounded by [timeout]. A pending animation
/// (e.g. a slowly loading network cover image) can keep the scheduler busy
/// past the settle deadline; in that case we pump a final frame and proceed so
/// a slow image never aborts the whole run.
Future<void> pumpStable(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await tester.pumpAndSettle(timeout);
  } on Exception {
    // Settle timed out (e.g. a cover image is still fetching). Pump a final
    // frame to render whatever has loaded so far, then continue.
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Rasterizes the [RepaintBoundary] tagged with [screenshotBoundaryKey] and
/// writes the PNG to [screenshotsDir] as `<name>.png` (creating the directory
/// if needed). Uses the in-process render tree — no test driver required.
Future<File> capture(String name, {double? pixelRatio}) async {
  if (!await screenshotsDir.exists()) {
    await screenshotsDir.create(recursive: true);
  }
  final boundary = screenshotBoundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: pixelRatio ?? 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(p.join(screenshotsDir.path, '$name.png'));
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

/// Runs [body] with the test view fixed to [ff]'s logical size and device
/// pixel ratio, restoring the previous view afterwards.
Future<T> withFormFactor<T>(
  WidgetTester tester,
  FormFactor ff,
  Future<T> Function() body,
) async {
  final view = tester.view;
  final oldPixelRatio = view.devicePixelRatio;
  final oldPhysicalSize = view.physicalSize;

  view.devicePixelRatio = ff.devicePixelRatio;
  view.physicalSize = Size(
    ff.width * ff.devicePixelRatio,
    ff.height * ff.devicePixelRatio,
  );

  try {
    return await body();
  } finally {
    view.devicePixelRatio = oldPixelRatio;
    view.physicalSize = oldPhysicalSize;
  }
}
