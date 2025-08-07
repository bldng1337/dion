import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

export 'package:rdion_runtime/rdion_runtime.dart'
    hide Entry, EntryDetailed, RustLib, Setting;

class Extension extends ChangeNotifier {
  Extension(this.data, this._proxy, this.isenabled, this.settings, this._meta);
  final rust.ExtensionData data;
  final rust.SourceExtensionProxy _proxy;
  final List<Setting<dynamic, SourceExtensionSettingMetaData<dynamic>>>
  settings;
  ExtensionMetaData _meta;
  bool isenabled;
  bool loading = false;

  ExtensionMetaData get meta => _meta;

  set meta(ExtensionMetaData value) {
    _meta = value;
    locate<Database>()
        .setExtensionMetaData(value)
        .then((_) => notifyListeners());
  }

  String get id => data.id;

  String get name {
    return data.name.replaceAll('-', ' ').capitalize;
  }

  rust.SourceExtensionProxy get internalProxy => _proxy;

  static Future<Extension> fromProxy(
    rust.SourceExtensionProxy proxy,
    Database db,
  ) async {
    await proxy.setEnabled(enabled: true); //TODO: Rework this
    final settingids = await proxy.getSettingsIds();
    await proxy.setEnabled(enabled: false);
    final extdata = await proxy.getData();
    final extmeta = await db.getExtensionMetaData(extdata);
    return Extension(
      extdata,
      proxy,
      await proxy.isEnabled(),
      await Future.wait(
        settingids.map((id) async {
          final set = await proxy.getSetting(name: id);
          final setting = set.setting.toSetting(
            SourceExtensionSettingMetaData(id, set, proxy),
          );
          return setting;
        }),
      ),
      extmeta,
    );
  }

  Future<void> enable() async {
    if (isenabled || loading) return;
    if (!meta.enabled) {
      meta = meta.copyWith(enabled: true);
    }
    loading = true;
    notifyListeners();
    await _proxy.setEnabled(enabled: true);
    isenabled = true;
    loading = false;
    notifyListeners();
  }

  Future<void> disable() async {
    if (!isenabled || loading) return;
    if (meta.enabled) {
      meta = meta.copyWith(enabled: false);
    }
    loading = true;
    notifyListeners();
    await _proxy.setEnabled(enabled: false);
    isenabled = false;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _proxy.dispose();
    super.dispose();
  }

  Future<List<Entry>> browse(
    int page,
    rust.Sort sort, {
    rust.CancelToken? token,
  }) async {
    final db = locate<Database>();
    final res = await _proxy.browse(page: page, sort: sort, token: token);
    return Future.wait(
      res.map((entry) => EntryImpl(entry, this)).map((entry) async {
        final saved = await db.isSaved(entry);
        if (saved != null) {
          return saved;
        }
        return entry;
      }).toList(),
    );
  }

  Future<List<Entry>> search(
    int page,
    String filter, {
    rust.CancelToken? token,
  }) async {
    final res = await _proxy.search(page: page, filter: filter, token: token);
    final db = locate<Database>();
    return await Future.wait(
      res.map((entry) => EntryImpl(entry, this)).map((entry) async {
        final saved = await db.isSaved(entry);
        if (saved != null) {
          return saved;
        }
        return entry;
      }).toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Extension && other._proxy == _proxy;
  }

  @override
  int get hashCode => _proxy.hashCode;

  Future<void> toggle() async {
    if (isenabled) {
      disable();
    } else {
      enable();
    }
  }
}

class SourceExtension {
  final _extensions = <Extension>[];

  Future<SourceExtension> init() async {
    await rust.RustLib.init();
    await reload();
    return this;
  }

  static Future<void> ensureInitialized() async {
    register<SourceExtension>(await SourceExtension().init());
  }

  Stream<List<Entry>> browse(
    int page,
    rust.Sort sort, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  }) {
    return Stream.fromFutures(
      getExtensions(extfilter: extfilter)
          .where((e) => e.isenabled)
          .map((e) async => (await e.browse(page, sort)).toList()),
    );
  }

  Stream<List<Entry>> search(
    int page,
    String filter, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  }) {
    return Stream.fromFutures(
      getExtensions(extfilter: extfilter)
          .where((e) => e.isenabled)
          .map((e) async => (await e.search(page, filter)).toList()),
    );
  }

  Future<EntryDetailed> detail(Entry e, {rust.CancelToken? token}) async {
    if (e is EntryDetailedImpl) {
      throw Exception('Use update(EntrySaved) instead');
    }
    return EntryDetailedImpl(
      await e.extension._proxy.detail(
        entryid: e.id,
        token: token,
        settings: {},
      ),
      e.extension,
    );
  }

  Future<EntrySaved> update(EntrySaved e, {rust.CancelToken? token}) async {
    final newdata = await e.extension._proxy.detail(
      entryid: e.id,
      token: token,
      settings: e.rawsettings ?? {},
    );
    e.entry = newdata;
    await e.save();
    return e;
  }

  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) async {
    final entry = ep.entry;
    return SourcePath(
      ep,
      await ep.extension._proxy.source(
        epid: ep.episode.id,
        token: token,
        settings: entry is EntrySaved ? entry.rawsettings ?? {} : {},
      ),
    );
  }

  Future<Entry?> fromUrl(String url, {rust.CancelToken? token}) async {
    for (final e in _extensions) {
      final result = await e._proxy.fromurl(url: url, token: token);
      if (result != null) {
        return EntryImpl(result, e);
      }
    }
    return null;
  }

  Extension getExtension(String id) {
    final ext = tryGetExtension(id);
    if (ext == null) {
      throw ExtensionNotFoundException(id);
    }
    return ext;
  }

  Extension? tryGetExtension(String id) {
    return _extensions.where((e) => e.data.id == id).firstOrNull;
  }

  Future<void> reload() async {
    for (final e in _extensions) {
      e.dispose();
    }
    _extensions.clear();
    final dir = await locateAsync<DirectoryProvider>();
    final extmanager = rust.SourceExtensionManagerProxy(
      path: dir.extensionpath.absolute.path,
    );
    final exts = await extmanager.getExtensions();
    extmanager.dispose();
    final db = await locateAsync<Database>();
    _extensions.addAll(
      await Future.wait(exts.map((e) => Extension.fromProxy(e, db))),
    );
    for (final e in _extensions) {
      if (e.meta.enabled) {
        e.enable();
      }
    }
  }

  List<Extension> getExtensions({bool Function(Extension e)? extfilter}) {
    return _extensions.where((e) => extfilter == null || extfilter(e)).toList();
  }
}

class ExtensionNotFoundException implements Exception {
  final String id;
  const ExtensionNotFoundException(this.id);

  @override
  String toString() {
    return 'Extension $id not found';
  }
}
