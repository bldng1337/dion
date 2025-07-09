import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
export 'package:rdion_runtime/rdion_runtime.dart' 
    hide Entry, EntryDetailed, RustLib;

class Extension extends ChangeNotifier {
  Extension(this.data, this._proxy, this.isenabled, this.settings, this._meta);
  final rust.ExtensionData data;
  final rust.SourceExtensionProxy _proxy;
  final List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>> settings;
  ExtensionMetaData _meta;
  bool isenabled;
  bool loading = false;

  ExtensionMetaData get meta => _meta;

  set meta(ExtensionMetaData value) {
    _meta = value;
    locate<Database>().setExtensionMetaData(this, value);
    notifyListeners();
  }

  String get id => data.id;

  String get name {
    return data.name.replaceAll('-', ' ').capitalize;
  }

  rust.SourceExtensionProxy get internalProxy => _proxy;

  static Future<Extension> fromProxy(
      rust.SourceExtensionProxy proxy, Database db,) async {
    final settingids = await proxy.getSettingsIds();
    final extdata = await proxy.getData();
    final extmeta = await db.getExtensionMetaData(extdata);
    return Extension(
      extdata,
      proxy,
      await proxy.isEnabled(),
      await Future.wait(
        settingids.map((id) async {
          final set = await proxy.getSetting(name: id);
          final setting = switch (set.setting.val) {
            final rust.Settingvalue_String val =>
              Setting<String, ExtensionSettingMetaData<String>>.fromValue(
                val.defaultVal,
                val.val,
                ExtensionSettingMetaData(id, set, proxy),
              ),
            final rust.Settingvalue_Number val =>
              Setting<double, ExtensionSettingMetaData<double>>.fromValue(
                val.defaultVal,
                val.val,
                ExtensionSettingMetaData(id, set, proxy),
              ),
            final rust.Settingvalue_Boolean val =>
              Setting<bool, ExtensionSettingMetaData<bool>>.fromValue(
                val.defaultVal,
                val.val,
                ExtensionSettingMetaData(id, set, proxy),
              ),
          };
          logger.i('Runtime type: ${setting.runtimeType}');
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
      res.map((e) => e.wrap(this)).map((ent) async {
        final saved = await db.isSaved(ent);
        if (saved != null) {
          return saved;
        }
        return ent;
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
      res.map((e) => e.wrap(this)).map((ent) async {
        final saved = await db.isSaved(ent);
        if (saved != null) {
          return saved;
        }
        return ent;
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

class ExtensionSettingMetaData<T> extends MetaData<T> {
  final String id;
  final rust.ExtensionSetting setting;
  final rust.SourceExtensionProxy extension;
  const ExtensionSettingMetaData(this.id, this.setting, this.extension);

  @override
  void onChange(T v) {
    final newval = switch (setting.setting.val) {
      final rust.Settingvalue_String val =>
        rust.Settingvalue_String(val: v as String, defaultVal: val.defaultVal),
      final rust.Settingvalue_Number val =>
        rust.Settingvalue_Number(val: v as double, defaultVal: val.defaultVal),
      final rust.Settingvalue_Boolean val =>
        rust.Settingvalue_Boolean(val: v as bool, defaultVal: val.defaultVal),
    };
    extension.setSetting(name: id, value: newval);
  }
}

abstract class SourceExtension {
  Future<void> reload();
  Extension getExtension(String id);
  Extension? tryGetExtension(String id);

  List<Extension> getExtensions({bool Function(Extension e)? extfilter});

  Stream<List<Entry>> search(
    int page,
    String filter, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  });
  Stream<List<Entry>> browse(
    int page,
    rust.Sort sort, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  });
  Future<EntryDetailed> detail(
    Entry e, {
    rust.CancelToken? token,
  });
  Future<EntrySaved> update(
    EntrySaved e, {
    rust.CancelToken? token,
  });
  Future<Entry?> fromUrl(
    String url, {
    rust.CancelToken? token,
  });
  Future<SourcePath> source(
    EpisodePath ep, {
    rust.CancelToken? token,
  });

  static Future<void> ensureInitialized() async {
    register<SourceExtension>(await SourceExtensionImpl().init());
  }
}

class SourceExtensionImpl implements SourceExtension {
  final _extensions = <Extension>[];

  Future<SourceExtensionImpl> init() async {
    await rust.RustLib.init();
    await reload();
    return this;
  }

  @override
  Stream<List<Entry>> browse(
    int page,
    rust.Sort sort, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  }) {
    return Stream.fromFutures(
      getExtensions(extfilter: extfilter).where((e) => e.isenabled).map(
            (e) async =>
                (await e._proxy.browse(page: page, sort: sort, token: token))
                    .map((ent) => ent.wrap(e))
                    .toList(),
          ),
    );
  }

  @override
  Stream<List<Entry>> search(
    int page,
    String filter, {
    bool Function(Extension e)? extfilter,
    rust.CancelToken? token,
  }) {
    return Stream.fromFutures(
      getExtensions(extfilter: extfilter).where((e) => e.isenabled).map(
            (e) async => (await e._proxy
                    .search(page: page, filter: filter, token: token))
                .map((ent) => ent.wrap(e))
                .toList(),
          ),
    );
  }

  @override
  Future<EntryDetailed> detail(
    Entry e, {
    rust.CancelToken? token,
    Map<String, rust.Setting> settings = const {},
  }) async {
    return EntryDetailedImpl(
      await e.extension._proxy
          .detail(entryid: e.id, token: token, settings: settings),
      e.extension,
    );
  }

  @override
  Future<EntrySaved> update(
    EntrySaved e, {
    rust.CancelToken? token,
    Map<String, rust.Setting> settings = const {},
  }) async {
    return EntrySavedImpl(
      await e.extension._proxy
          .detail(entryid: e.id, token: token, settings: settings),
      e.extension,
      e.episodedata,
      e.episode,
      e.categories,
    );
  }

  @override
  Future<SourcePath> source(
    EpisodePath ep, {
    rust.CancelToken? token,
    Map<String, rust.Setting> settings = const {},
  }) async {
    return SourcePath(
      ep,
      await ep.extension._proxy
          .source(epid: ep.episode.id, token: token, settings: settings),
    );
  }

  @override
  Future<Entry?> fromUrl(
    String url, {
    rust.CancelToken? token,
  }) async {
    for (final e in _extensions) {
      final result = await e._proxy.fromurl(url: url, token: token);
      if (result != null) {
        return result.wrap(e);
      }
    }
    return null;
  }

  @override
  Extension getExtension(String id) {
    return tryGetExtension(id)!;
  }

  @override
  Extension? tryGetExtension(String id) {
    return _extensions.where((e) => e.data.id == id).firstOrNull;
  }

  @override
  Future<void> reload() async {
    for (final e in _extensions) {
      e.dispose();
    }
    _extensions.clear();
    final dir = await locateAsync<DirectoryProvider>();
    final extmanager =
        rust.SourceExtensionManagerProxy(path: dir.extensionpath.absolute.path);
    final exts = await extmanager.getExtensions();
    extmanager.dispose();
    final db = await locateAsync<Database>();
    _extensions.addAll(
      await Future.wait(
        exts.map((e) => Extension.fromProxy(e, db)),
      ),
    );
    for (final e in _extensions) {
      if (e.meta.enabled) {
        e.enable();
      }
    }
  }

  @override
  List<Extension> getExtensions({bool Function(Extension e)? extfilter}) {
    return _extensions.where((e) => extfilter == null || extfilter(e)).toList();
  }
}
