import 'package:dionysos/data/entry.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/service.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
export 'package:rdion_runtime/rdion_runtime.dart' hide Entry, EntryDetailed;

class Extension {
  Extension(this.data, this._proxy, this.isenabled);
  final rust.ExtensionData data;
  final rust.ExtensionProxy _proxy;
  bool isenabled;

  String get id => data.id;

  static Future<Extension> fromProxy(rust.ExtensionProxy proxy) async {
    return Extension(await proxy.data(), proxy, await proxy.isEnabled());
  }

  Future<void> enable() async {
    if (isenabled) return;
    await _proxy.enable();
    isenabled = true;
  }

  Future<void> disable() async {
    if (!isenabled) return;
    await _proxy.disable();
    isenabled = false;
  }

  void dispose() {
    _proxy.dispose();
  }

  Future<List<Entry>> browse(
    int page,
    rust.Sort sort, {
    rust.CancelToken? token,
  }) async {
    final res = await _proxy.browse(page: page, sort: sort, token: token);
    return res.map((e) => e.wrap(this)).toList();
  }

  Future<List<Entry>> search(
    int page,
    String filter, {
    rust.CancelToken? token,
  }) async {
    final res = await _proxy.search(page: page, filter: filter, token: token);
    return res.map((e) => e.wrap(this)).toList();
  }

  @override
  bool operator ==(Object other) {
    return other is Extension && other._proxy == _proxy;
  }

  @override
  int get hashCode => _proxy.hashCode;
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
  Future<EntryDetailedImpl> detail(
    Entry e, {
    rust.CancelToken? token,
  }) async {
    return EntryDetailedImpl(
      await e.extension._proxy.detail(entryid: e.id, token: token),
      e.extension,
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
