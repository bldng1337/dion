import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/settings.dart';
import 'package:flutter/widgets.dart' show ChangeNotifier, Color, IconData;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
export 'package:rdion_runtime/rdion_runtime.dart' hide Entry, EntryDetailed;

class Extension extends ChangeNotifier {
  Extension(this.data, this._proxy, this.isenabled, this.settings);
  final rust.ExtensionData data;
  final rust.ExtensionProxy _proxy;
  final List<Setting<dynamic, ExtensionMetaData<dynamic>>> settings;
  bool isenabled;
  bool loading = false;

  String get id => data.id;

  String get name {
    return data.name.replaceAll('-', ' ').capitalize;
  }

  static Future<Extension> fromProxy(rust.ExtensionProxy proxy) async {
    return Extension(
      await proxy.data(),
      proxy,
      await proxy.isEnabled(),
      await Future.wait(
        (await proxy.settingIds()).map((id) async {
          final set = await proxy.getSetting(name: id);
          final setting =
              Setting<dynamic, ExtensionMetaData<dynamic>>.fromValue(
            set.val.val,
            set.val.defaultVal,
            ExtensionMetaData(id, set, proxy),
          );
          return setting;
        }).toList(),
      ),
    );
  }

  Future<void> enable() async {
    if (isenabled || loading) return;
    loading = true;
    notifyListeners();
    await _proxy.enable();
    isenabled = true;
    loading = false;
    notifyListeners();
  }

  Future<void> disable() async {
    if (!isenabled || loading) return;
    loading = true;
    notifyListeners();
    await _proxy.disable();
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

class ExtensionMetaData<T> extends MetaData<T> {
  final String id;
  final rust.Setting setting;
  final rust.ExtensionProxy extension;
  const ExtensionMetaData(this.id, this.setting, this.extension);

  @override
  void onChange(T v) {
    final newval = switch (setting.val) {
      final rust.Settingvalue_String val =>
        rust.Settingvalue_String(val: v as String, defaultVal: val.defaultVal),
      final rust.Settingvalue_Number val =>
        rust.Settingvalue_Number(val: v as double, defaultVal: val.defaultVal),
      final rust.Settingvalue_Boolean val =>
        rust.Settingvalue_Boolean(val: v as bool, defaultVal: val.defaultVal),
    };
    extension.setSetting(name: id, setting: newval);
  }
}

abstract class SourceExtension {
  Future<void> reload();
  Extension getExtension(String id);

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
  }) async {
    return EntryDetailedImpl(
      await e.extension._proxy.detail(entryid: e.id, token: token),
      e.extension,
    );
  }

  @override
  Future<EntrySaved> update(
    EntrySaved e, {
    rust.CancelToken? token,
  }) async {
    return EntrySavedImpl(
      await e.extension._proxy.detail(entryid: e.id, token: token),
      e.extension,
      e.episodedata,
    );
  }

  @override
  Future<SourcePath> source(
    EpisodePath ep, {
    rust.CancelToken? token,
  }) async {
    return SourcePath(
      ep,
      await ep.extension._proxy.source(epid: ep.episode.id, token: token),
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
    return _extensions.firstWhere((e) => e.data.id == id);
  }

  @override
  Future<void> reload() async {
    for (final e in _extensions) {
      e.dispose();
    }
    _extensions.clear();
    final dir = await locateAsync<DirectoryProvider>();
    final extmanager =
        rust.ExtensionManagerProxy(path: dir.extensionpath.absolute.path);
    final exts = await extmanager.getExtensions();
    _extensions.addAll(
      await Future.wait(
        exts.map((e) => Extension.fromProxy(e)),
      ),
    );
    for (final e in _extensions) {
      await e.enable();
    }
    extmanager.dispose();
  }

  @override
  List<Extension> getExtensions({bool Function(Extension e)? extfilter}) {
    return _extensions.where((e) => extfilter == null || extfilter(e)).toList();
  }
}
