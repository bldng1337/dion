import 'dart:async';

import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/customui_store.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/version.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:pub_semver/pub_semver.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

/// Inbuilt debug/test entry-processor ("tracker") mock. Lets the auto-add
/// rules, the save picker and the entry-extension settings be exercised
/// end-to-end without a real tracker extension. Only registered in debug
/// builds (see [ExtensionService]).
///
/// `triggerMapEntry` is deliberately false: a real bound extension running its
/// processor loop would call `proxy.mapEntry` on this instance, and as a mock
/// it has no proxy. Attachment still works everywhere that only checks for the
/// EntryProcessor type.
// ignore: avoid_implementing_value_types
class MockTrackerExtension with ChangeNotifier implements Extension {
  static const String mockId = 'dion.mocktracker.debug';

  MockTrackerExtension() : _meta = const ExtensionMetaData(mockId, true);

  ExtensionMetaData _meta;

  static final rust.ExtensionData _data = rust.ExtensionData(
    id: mockId,
    name: 'Mock Tracker',
    url: 'https://www.example.com',
    icon: 'https://loremflickr.com/200/200?random=2',
    desc:
        'Inbuilt debug/test tracker mock with an EntryProcessor type. Used to '
        'test auto-add rules and entry extension attachment. Only present in '
        'debug builds.',
    author: const ['dion-debug'],
    tags: const ['mock', 'debug', 'test', 'tracker'],
    lang: const ['en'],
    nsfw: false,
    mediaType: const {
      rust.MediaType.video,
      rust.MediaType.comic,
      rust.MediaType.audio,
      rust.MediaType.book,
    },
    extensionType: {
      const rust.ExtensionType.entryProcessor(
        triggerMapEntry: false,
        triggerOnEntryActivity: true,
      ),
    },
    version: '1.0.0',
    license: 'MIT',
    compatible: true,
  );

  @override
  rust.ExtensionData get data => _data;

  @override
  ExtensionMetaData get meta => _meta;

  @override
  set meta(ExtensionMetaData value) {
    // The real extension persists this to the DB; the mock is not persisted.
    _meta = value;
    notifyListeners();
  }

  @override
  bool isenabled = true;

  @override
  bool loading = false;

  @override
  final CustomUIStore uiStore = CustomUIStore();

  @override
  final CustomUIChangeBus settingChanges = CustomUIChangeBus();

  @override
  List<Account> get accounts => const [];

  @override
  Map<rust.SettingKind, List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>>
  get settings => _settings;

  static final Map<
    rust.SettingKind,
    List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
  >
  _settings = {for (final kind in rust.SettingKind.values) kind: const []};

  @override
  String get id => data.id;

  @override
  String get name => 'Mock Tracker';

  @override
  bool get searchEnabled => _meta.searchEnabled;

  @override
  set searchEnabled(bool value) {
    if (_meta.searchEnabled != value) {
      meta = _meta.copyWith(searchEnabled: value);
    }
  }

  @override
  Version get version => parseVersion(data.version);

  // -- Data-producing methods (a tracker provides none) ----------------------

  @override
  DataSource<Entry> browse({rust.CancelToken? token}) {
    return PageAsyncSource((page) async => Page.last(const []))..name = name;
  }

  @override
  DataSource<Entry> search(String filter, {rust.CancelToken? token}) {
    return PageAsyncSource((page) async => Page.last(const []))..name = name;
  }

  @override
  Future<EntryDetailed> detail(Entry e, {rust.CancelToken? token}) {
    throw UnsupportedError('MockTrackerExtension provides no entries');
  }

  @override
  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) {
    throw UnsupportedError('MockTrackerExtension provides no sources');
  }

  // -- Proxy-touching methods (safe no-ops) ----------------------------------

  @override
  Future<void> enable() async {
    if (isenabled || loading) return;
    loading = true;
    notifyListeners();
    isenabled = true;
    loading = false;
    notifyListeners();
  }

  @override
  Future<void> disable() async {
    if (!isenabled || loading) return;
    loading = true;
    notifyListeners();
    isenabled = false;
    loading = false;
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    if (isenabled) {
      await disable();
    } else {
      await enable();
    }
  }

  @override
  Future<void> save() async {}

  @override
  Future<List<rust.Permission>> getPermissions() async => const [];

  @override
  Future<bool> hasPermission(rust.Permission permission) async => true;

  @override
  Future<void> grantPermission(rust.Permission permission) async {}

  @override
  Future<void> removePermission(rust.Permission permission) async {}

  @override
  Future<rust.EventResult?> event({
    required rust.EventData event,
    rust.CancelToken? token,
  }) async => null;

  @override
  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async => false;

  @override
  Future<void> onEntryActivity(
    rust.EntryActivity activity,
    EntryDetailed entry,
    Map<String, rust.Setting> settings, {
    rust.CancelToken? token,
  }) async {}

  @override
  Future<void> runAction(rust.Action action, {rust.CancelToken? token}) async {}

  @override
  Future<EntrySaved> refreshEntryExtension(
    EntrySaved e,
    Extension extension, {
    rust.CancelToken? token,
  }) async => e;

  @override
  Future<rust.EntryDetailedResult> mapEntry(
    rust.EntryDetailed entry,
    Map<String, rust.Setting> settings, {
    rust.CancelToken? token,
  }) async => rust.EntryDetailedResult(entry: entry, settings: settings);

  @override
  Future<void> remapEntry(
    EntrySaved e, {
    String? only,
    bool runMissing = true,
    rust.CancelToken? token,
  }) => remapSavedEntry(e, only: only, runMissing: runMissing, token: token);

  @override
  Future<void> recomposeEntry(EntrySaved e) {
    return locate<ExtensionService>().withEntryLock(
      e,
      () => remapSavedEntry(e, runMissing: false),
    );
  }

  @override
  T getExtensionType<T extends rust.ExtensionType>() {
    final extType = getExtensionTypeOrNull<T>();
    if (extType == null) {
      throw Exception('Extension type $T not found for extension $id');
    }
    return extType;
  }

  @override
  T? getExtensionTypeOrNull<T extends rust.ExtensionType>() {
    return data.extensionType.whereType<T>().firstOrNull;
  }

  @override
  void dispose() {
    // The real extension disposes its rust proxy here; the mock has none.
    super.dispose();
  }
}
