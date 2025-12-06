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
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:pub_semver/pub_semver.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

export 'package:rdion_runtime/rdion_runtime.dart'
    hide Entry, EntryDetailed, RustLib, Setting;

class Extension extends ChangeNotifier {
  Extension(this.data, this._proxy, this.isenabled, this.settings, this._meta);
  final rust.ExtensionData data;
  final rust.ProxyExtension _proxy;
  final Map<
    rust.SettingKind,
    List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
  >
  settings;
  ExtensionMetaData _meta;
  bool isenabled;
  bool loading = false;

  ExtensionMetaData get meta => _meta;

  Version get version => Version.parse(data.version);

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

  static Future<Extension> fromProxy(
    rust.ProxyExtension proxy,
    Database db,
  ) async {
    final Map<
      rust.SettingKind,
      List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
    >
    settingsmap = {};
    // Kind of stopgap solution until we persist settings
    await proxy.setEnabled(enabled: true);
    for (final kind in rust.SettingKind.values) {
      final settingids = await proxy.getSettingIds(kind: kind);
      final settings = await Future.wait(
        settingids.map((id) async {
          final set = await proxy.getSetting(id: id, kind: kind);
          final setting =
              Setting<dynamic, ExtensionSettingMetaData<dynamic>>.fromValue(
                set.default_.data,
                set.value.data,
                ExtensionSettingMetaData(
                  kind,
                  proxy,
                  id,
                  set.label,
                  set.visible,
                  set.ui,
                ),
              );
          return setting;
        }),
      );
      settingsmap[kind] = settings;
    }
    final extdata = await proxy.getExtensionData();
    final extmeta = await db.getExtensionMetaData(extdata);
    await proxy.setEnabled(enabled: extmeta.enabled);
    return Extension(
      extdata,
      proxy,
      await proxy.isEnabled(),
      settingsmap,
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

  Future<List<Entry>> browse(int page, {rust.CancelToken? token}) async {
    final db = locate<Database>();
    final res = await _proxy.browse(page: page, token: token);
    //TODO: Take advantage of the additional data that EntryList Provides
    return Future.wait(
      res.content.map((entry) => EntryImpl(entry, id)).map((entry) async {
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
      res.content.map((entry) => EntryImpl(entry, id)).map((entry) async {
        final saved = await db.isSaved(entry);
        if (saved != null) {
          return saved;
        }
        return entry;
      }).toList(),
    );
  }

  Future<EntryDetailed> detail(Entry e, {rust.CancelToken? token}) async {
    if (e.boundExtensionId != id) {
      throw Exception(
        'Extension mismatch: expected $id, got ${e.boundExtensionId}',
      );
    }
    final res = switch (e) {
      final EntrySaved saved => await _proxy.detail(
        entryid: saved.id,
        token: token,
        settings: saved.extensionSettings,
      ),
      final EntryDetailed detail => await _proxy.detail(
        entryid: detail.id,
        token: token,
        settings: detail.extensionSettings,
      ),
      final Entry entry => await _proxy.detail(
        entryid: entry.id,
        token: token,
        settings: {},
      ),
    };
    if (e is EntrySaved) {
      e.entry = res.entry;
      e.extensionSettings =
          res.settings; //TODO: Think about possible race conditions here
      return e;
    }
    return EntryDetailedImpl(res.entry, id, res.settings);
  }

  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) async {
    final entry = ep.entry;
    final res = await _proxy.source(
      epid: ep.episode.id,
      token: token,
      settings: entry.extensionSettings,
    );
    if (entry is EntrySaved) {
      entry.extensionSettings =
          res.settings; //TODO: Think about possible race conditions here
    }
    return SourcePath(ep, res.source);
  }

  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async {
    return await _proxy.handleUrl(url: url, token: token);
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

  Future<void> save() async {
    await _proxy.saveSettings();
    await _proxy.savePermissions();
  }
}

class SourceExtension with ChangeNotifier {
  final _extensions = <Extension>[];
  late final rust.ProxyAdapter adapter;
  bool loading = false;

  Future<SourceExtension> init() async {
    final dir = await locateAsync<DirectoryProvider>();
    await rust.RustLib.init();
    final managerpath = dir.extensionpath.sub('dion_extensions');
    await managerpath.create(recursive: true);
    final managerclient = await rust.ManagerClient.init(
      getClient: (data) async {
        final extensionPath = managerpath.sub('data').sub(data.id);
        await extensionPath.create(recursive: true);
        return rust.ExtensionClient.init(
          loadData: (key) async {
            try {
              final file = extensionPath.sub('store').getFile(key);
              if (!await file.exists()) {
                return '';
              }
              return await file.readAsString();
            } catch (e) {
              logger.e(
                'Failed to read data $key for extension $data',
                error: e,
              );
              return '';
            }
          },
          storeData: (String key, String value) async {
            try {
              final file = extensionPath.sub('store').getFile(key);
              await file.parent.create(recursive: true);
              await file.writeAsString(value);
            } catch (e) {
              logger.e(
                'Failed to store data $key for extension $data',
                error: e,
              );
            }
          },
          doAction: (rust.Action action) {},
          requestPermission: (rust.Permission permission, String? message) {
            logger.i('Requesting permission $permission for extension $data');
            //TODO: Implement this
            return false;
          },
          getPath: () async {
            final nativePath = extensionPath.sub('native');
            await nativePath.create(recursive: true);
            return nativePath.absolute.path;
          },
        );
      },
      getPath: () async {
        final nativePath = managerpath.sub('native');
        await nativePath.create(recursive: true);
        return nativePath.absolute.path;
      },
    );
    adapter = await rust.ProxyAdapter.initDion(client: managerclient);
    await reload();
    return this;
  }

  static Future<void> ensureInitialized() async {
    register<SourceExtension>(await SourceExtension().init());
  }

  Stream<List<Entry>> browse(
    int page, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  }) {
    return Stream.fromFutures(
      getExtensions(extfilter: extfilter)
          .where((e) => e.isenabled)
          .map((e) async => (await e.browse(page)).toList()),
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
    final ext = e.extension;
    if (ext == null) {
      throw Exception('Extension not found for id ${e.boundExtensionId}');
    }
    return await ext.detail(e, token: token);
  }

  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) async {
    final entry = ep.entry;
    final ext = entry.extension;
    if (ext == null) {
      throw Exception('Extension not found for id ${entry.boundExtensionId}');
    }
    return await ext.source(ep, token: token);
  }

  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async {
    for (final e in _extensions) {
      final result = await e.handleUrl(url, token: token);
      if (result) {
        return true;
      }
    }
    return false;
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
    loading = true;
    for (final e in _extensions) {
      e.dispose();
    }
    _extensions.clear();
    notifyListeners();
    final exts = await adapter.getExtensions();
    final db = await locateAsync<Database>();
    _extensions.addAll(
      await Future.wait(exts.map((e) => Extension.fromProxy(e, db))),
    );
    loading = false;
    notifyListeners();
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
