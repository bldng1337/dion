import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/extension.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/main.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/directoryprovider.dart';
import 'package:dionysos/utils/file_utils.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/action_dialog.dart';
import 'package:dionysos/views/custom_view.dart';
import 'package:dionysos/views/dialog/auth.dart';
import 'package:dionysos/views/extension/permission_dialog.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/widgets.dart' show ChangeNotifier;
import 'package:go_router/go_router.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
export 'package:rdion_runtime/rdion_runtime.dart'
    hide Entry, EntryDetailed, Row, RustLib, Setting, Account;

typedef CustomUIRow = rust.Row;

extension on rust.Source {
  rust.SourceType get type {
    return switch (this) {
      rust.Source_Epub() => rust.SourceType.epub,
      rust.Source_Pdf() => rust.SourceType.pdf,
      rust.Source_Imagelist() => rust.SourceType.imagelist,
      rust.Source_Video() => rust.SourceType.video,
      rust.Source_Audio() => rust.SourceType.audio,
      rust.Source_Paragraphlist() => rust.SourceType.paragraphlist,
    };
  }
}

class Account extends ChangeNotifier {
  final rust.ProxyExtension _proxy;
  final String extensionid;
  rust.Account data;
  Account(this._proxy, this.extensionid, this.data);

  String get domain => data.domain;
  String? get userName => data.userName;
  String? get cover => data.cover;
  rust.AuthData get authData => data.auth;
  rust.AuthCreds? get authCreds => data.creds;
  bool get isLoggedIn => data.creds != null;

  Extension get extension {
    return locate<ExtensionService>().getExtension(extensionid);
  }

  Future<void> logout() async {
    data = rust.Account(
      auth: data.auth,
      domain: data.domain,
      cover: data.cover,
      userName: data.userName,
    );
    await _proxy.invalidate(domain: data.domain);
    notifyListeners();
  }

  Future<void> auth() async {
    final result = await showDialog<rust.AuthCreds?>(
      context: navigatorKey.currentContext!,
      builder: (context) => AuthDialog(account: this),
    );
    if (result == null) {
      throw Exception('Authentication cancelled');
    }
    data = rust.Account(
      auth: data.auth,
      domain: data.domain,
      cover: data.cover,
      creds: result,
      userName: data.userName,
    );

    final res = await _proxy.validate(account: data);
    if (res == null) {
      throw Exception('Invalid credentials');
    }
    data = res;
    extension.save();
    notifyListeners();
  }
}

class Extension extends ChangeNotifier {
  final rust.ExtensionData data;
  final rust.ProxyExtension _proxy;
  final Map<
    rust.SettingKind,
    List<Setting<dynamic, ExtensionSettingMetaData<dynamic>>>
  >
  settings;
  final List<Account> accounts;
  ExtensionMetaData _meta;
  bool isenabled;
  bool loading = false;
  Extension(
    this.data,
    this._proxy,
    this.isenabled,
    this.settings,
    this._meta,
    this.accounts,
  );

  @override
  int get hashCode => _proxy.hashCode;

  String get id => data.id;

  ExtensionMetaData get meta => _meta;

  set meta(ExtensionMetaData value) {
    _meta = value;
    locate<Database>()
        .setExtensionMetaData(value)
        .then((_) => notifyListeners());
  }

  String get name {
    return data.name.replaceAll('-', ' ').capitalize;
  }

  Version get version => Version.parse(data.version);

  @override
  bool operator ==(Object other) {
    return other is Extension && other._proxy == _proxy;
  }

  T getExtensionType<T extends rust.ExtensionType>() {
    final extType = getExtensionTypeOrNull<T>();
    if (extType == null) {
      throw Exception('Extension type $T not found for extension $id');
    }
    return extType;
  }

  T? getExtensionTypeOrNull<T extends rust.ExtensionType>() {
    return data.extensionType.whereType<T>().firstOrNull;
  }

  DataSource<Entry> browse({rust.CancelToken? token}) {
    final db = locate<Database>();
    return PageAsyncSource((page) async {
      final res = await _proxy.browse(page: page, token: token);
      final entries = await Future.wait(
        res.content.map((entry) => EntryImpl(entry, id)).map((entry) async {
          final saved = await db.isSaved(entry);
          if (saved != null) {
            return saved;
          }
          return entry;
        }).toList(),
      );
      if (res.length != null && res.length! >= page) {
        return Page.last(entries);
      }
      if (res.hasnext != null && !res.hasnext!) {
        return Page.last(entries);
      }
      return Page.more(entries);
    })..name = name;
  }

  Future<void> runAction(rust.Action action, {rust.CancelToken? token}) async {
    switch (action) {
      case final rust.Action_OpenBrowser browse:
        logger.i('Opening browser for url ${action.url} for extension $data');
        await launchUrl(Uri.parse(browse.url));
      case final rust.Action_Popup popup:
        await showDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => ActionDialog(popup: popup, extension: this),
        );
      case final rust.Action_Nav nav:
        GoRouter.of(navigatorKey.currentContext!).go(
          '/custom',
          extra: [
            CustomUIViewData(
              title: nav.title,
              ui: nav.content,
              extension: this,
            ),
          ],
        );
      case final rust.Action_TriggerEvent triggerEvent:
        await event(
          event: rust.EventData.action(
            event: triggerEvent.event,
            data: triggerEvent.data,
          ),
        );
      case final rust.Action_NavEntry navEntry:
        GoRouter.of(
          navigatorKey.currentContext!,
        ).push('/detail', extra: [navEntry.entry]);
    }
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
        // token: token,
        settings: saved.extensionSettings,
      ),
      final EntryDetailed detail => await _proxy.detail(
        entryid: detail.id,
        // token: token,
        settings: detail.extensionSettings,
      ),
      final Entry entry => await _proxy.detail(
        entryid: entry.id,
        // token: token,
        settings: {},
      ),
    };
    if (e is EntrySaved) {
      var resEntry = res.entry;
      for (final entryExtension in e.entryExtensions) {
        final extension = entryExtension.extension;
        if (extension == null) {
          continue;
        }
        final processor = extension
            .getExtensionTypeOrNull<rust.ExtensionType_EntryProcessor>();
        if (!(extension.isenabled && processor != null)) {
          continue;
        }
        if (!processor.triggerMapEntry) {
          continue;
        }
        final mapRes = await extension._proxy.mapEntry(
          entry: resEntry,
          settings: entryExtension.extensionSettings,
          // token: token,
        );
        resEntry = mapRes.entry;
        entryExtension.extensionSettings =
            mapRes.settings; //TODO: Think about possible race conditions here
      }
      e.entry = resEntry;
      e.extensionSettings =
          res.settings; //TODO: Think about possible race conditions here
      return e;
    }
    return EntryDetailedImpl(res.entry, id, res.settings);
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

  Future<rust.EventResult?> event({
    required rust.EventData event,
    rust.CancelToken? token,
  }) async {
    return await _proxy.event(event: event, token: token);
  }

  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async {
    return await _proxy.handleUrl(url: url, token: token);
  }

  Future<void> save() async {
    await _proxy.saveSettings();
    await _proxy.savePermissions();
    await _proxy.saveAuthState();
  }

  Future<List<rust.Permission>> getPermissions() async {
    return await _proxy.getPermissions();
  }

  Future<void> removePermission(rust.Permission permission) async {
    await _proxy.removePermission(permission: permission);
  }

  DataSource<Entry> search(String filter, {rust.CancelToken? token}) {
    final db = locate<Database>();
    return PageAsyncSource((page) async {
      final res = await _proxy.search(page: page, filter: filter, token: token);
      final entries = await Future.wait(
        res.content.map((entry) => EntryImpl(entry, id)).map((entry) async {
          final saved = await db.isSaved(entry);
          if (saved != null) {
            return saved;
          }
          return entry;
        }).toList(),
      );
      if (res.length != null && res.length! >= page) {
        return Page.last(entries);
      }
      if (res.hasnext != null && !res.hasnext!) {
        return Page.last(entries);
      }
      return Page.more(entries);
    })..name = name;
  }

  Future<void> onEntryActivity(
    rust.EntryActivity activity,
    EntryDetailed entry,
    Map<String, rust.Setting> settings, {
    rust.CancelToken? token,
  }) async {
    await _proxy.onEntryActivity(
      activity: activity,
      entry: entry.toRust,
      settings: settings,
      token: token,
    );
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
      var resSource = res.source;
      for (final entryExtension in entry.sourceExtensions) {
        final extension = entryExtension.extension;
        if (extension == null) {
          continue;
        }
        final processor = extension
            .getExtensionTypeOrNull<rust.ExtensionType_SourceProcessor>();
        if (!(extension.isenabled && processor != null)) {
          continue;
        }
        if (!processor.sourcetypes.contains(res.source.type)) {
          continue;
        }
        final mapRes = await extension._proxy.mapSource(
          source: res.source,
          epid: ep.episode.id,
          settings: entryExtension.extensionSettings,
          token: token,
        );
        resSource = mapRes.source;
        entryExtension.extensionSettings =
            mapRes.settings; //TODO: Think about possible
      }
      return SourcePath(ep, resSource);
    }
    return SourcePath(ep, res.source);
  }

  Future<void> toggle() async {
    if (isenabled) {
      disable();
    } else {
      enable();
    }
  }

  static Future<Extension> fromProxy(
    rust.ProxyExtension proxy,
    Database db,
  ) async {
    final extdata = await proxy.getExtensionData();
    // Settings init
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
                  extdata.id,
                ),
              );
          return setting;
        }),
      );
      settingsmap[kind] = settings;
    }

    final accountsData = await proxy.getAccounts();

    final accounts = accountsData
        .map((data) => Account(proxy, extdata.id, data))
        .toList();

    final extmeta = await db.getExtensionMetaData(extdata);
    await proxy.setEnabled(enabled: extmeta.enabled);
    return Extension(
      extdata,
      proxy,
      await proxy.isEnabled(),
      settingsmap,
      extmeta,
      accounts,
    );
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

class ExtensionAdapter with ChangeNotifier {
  final _extensions = <Extension>[];
  final rust.ProxyAdapter adapter;
  ExtensionAdapter(this.adapter);

  Future<void> reload() async {
    _extensions.clear();
    final exts = await adapter.getExtensions();
    final db = await locateAsync<Database>();
    _extensions.addAll(
      await Future.wait(exts.map((e) => Extension.fromProxy(e, db))),
    );
  }

  DataSource<RemoteExtension> getRepoDataSource(rust.ExtensionRepo repo) {
    return PageAsyncSource((page) async {
      final res = await adapter.browseRepo(repo: repo, page: page);
      final data = res.content.map((e) => RemoteExtension(this, e)).toList();
      if (res.length != null && res.length! >= page) {
        return Page.last(data);
      }
      if (res.hasnext != null && !res.hasnext!) {
        return Page.last(data);
      }
      return Page.more(data);
    });
  }

  Future<RemoteExtensionRepo> getRepo(String url) async {
    return RemoteExtensionRepo(this, await adapter.getRepo(url: url));
  }

  Future<void> install(String location) async {
    final ext = await adapter.install(location: location);
    final db = await locateAsync<Database>();
    final newext = await Extension.fromProxy(ext, db);
    _extensions.removeWhere((e) => e.data.id == newext.data.id);
    _extensions.add(newext);
    notifyListeners();
  }

  Future<void> uninstall(Extension ext) async {
    await adapter.uninstall(ext: ext._proxy);
    _extensions.remove(ext);
    notifyListeners();
  }
}

class RemoteExtension {
  final ExtensionAdapter adapter;
  final rust.RemoteExtension data;

  String get remoteId => data.remoteId;
  String get id => data.id;
  String get name => data.name;
  String get url => data.url;
  rust.Link? get cover => data.cover;
  String get version => data.version;
  bool get compatible => data.compatible;

  RemoteExtension(this.adapter, this.data);

  Future<void> install() async {
    await adapter.install(data.remoteId);
  }
}

class RemoteExtensionRepo {
  final ExtensionAdapter adapter;
  final rust.ExtensionRepo data;
  RemoteExtensionRepo(this.adapter, this.data);

  Future<void> install() async {
    await adapter.install(data.remoteId);
  }

  Future<List<RemoteExtension>> browse({int page = 1}) async {
    final res = await adapter.adapter.browseRepo(repo: data, page: page);
    return res.content.map((e) => RemoteExtension(adapter, e)).toList();
  }
}

const storage =
    FlutterSecureStorage(); //We just make it static as i dont want to init it multiple times or pass a ref around i dont think it really matters as we would mock ExtensionService and not this impl. If that changes the refactor should be trivial

class ExtensionService with ChangeNotifier {
  final Map<String, ExtensionAdapter> _adapters = {};
  bool loading = false;

  Future<rust.ManagerClient> getClient(String adapter) async {
    final dir = await locateAsync<DirectoryProvider>();
    final managerpath = dir.extensionpath.sub('dion_extensions');
    await managerpath.create(recursive: true);
    return await rust.ManagerClient.init(
      getClient: (data) async {
        final extensionPath = managerpath.sub('data').sub(data.id);
        await extensionPath.create(recursive: true);
        return rust.ExtensionClient.init(
          setEntrySetting: (entryId, key, value) async {
            final db = locate<Database>();
            final entry = await db.getSavedById(entryId);
            if (entry == null) {
              return;
            }
            final entryExts = entry.entryExtensions
                .where((ext) => ext.extensionId == data.id)
                .firstOrNull
                ?.extensionSettings;
            if (entryExts != null && entryExts.containsKey(key)) {
              entryExts[key] = entryExts[key]!.copyWith(value: value);
              await entry.save();
              return;
            }
            final sourceExts = entry.sourceExtensions
                .where((ext) => ext.extensionId == data.id)
                .firstOrNull
                ?.extensionSettings;
            if (sourceExts != null && sourceExts.containsKey(key)) {
              sourceExts[key] = sourceExts[key]!.copyWith(value: value);
              await entry.save();
              return;
            }
          },
          loadDataSecure: (key) async {
            try {
              final value = await storage.read(key: '${data.id}_$key');
              return value ?? '';
            } catch (e) {
              logger.e(
                'Failed to read secure data $key for extension $data',
                error: e,
              );
              return '';
            }
          },
          storeDataSecure: (String key, String value) async {
            try {
              await storage.write(key: '${data.id}_$key', value: value);
            } catch (e) {
              logger.e(
                'Failed to store secure data $key for extension $data',
                error: e,
              );
            }
          },
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
          doAction: (rust.Action action) async {
            await getExtension(data.id).runAction(action);
          },
          requestPermission:
              (rust.Permission permission, String? message) async {
                logger.i(
                  'Requesting permission $permission for extension $data',
                );
                return await requestPermissionFromUser(
                  extensionData: data,
                  permission: permission,
                  message: message,
                );
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
  }

  Future<ExtensionService> init() async {
    await rust.RustLib.init();
    _adapters['dion'] = ExtensionAdapter(
      await rust.ProxyAdapter.initDion(
        client: await getClient('dion_extensions'),
      ),
    );
    for (final adapter in _adapters.values) {
      adapter.addListener(() {
        notifyListeners();
      });
    }
    await reload();
    return this;
  }

  Future<EntryDetailed> detail(Entry e, {rust.CancelToken? token}) async {
    final ext = e.extension;
    if (ext == null) {
      throw Exception('Extension not found for id ${e.boundExtensionId}');
    }
    return await ext.detail(e, token: token);
  }

  Extension getExtension(String id) {
    final ext = tryGetExtension(id);
    if (ext == null) {
      throw ExtensionNotFoundException(id);
    }
    return ext;
  }

  Iterable<Extension> getExtensions({bool Function(Extension e)? extfilter}) {
    return _adapters.values
        .expand((e) => e._extensions)
        .where((e) => extfilter == null || extfilter(e));
  }

  Future<bool> handleUrl(String url, {rust.CancelToken? token}) async {
    for (final e in getExtensions()) {
      final extUrlType = e
          .getExtensionTypeOrNull<rust.ExtensionType_URLHandler>();
      if (extUrlType == null) {
        continue;
      }
      if (!extUrlType.urlPatterns.any(
        (pattern) => RegExp(pattern).hasMatch(url),
      )) {
        continue;
      }
      final result = await e.handleUrl(url, token: token);
      if (result) {
        return true;
      }
    }
    return false;
  }

  Future<void> reload() async {
    loading = true;
    notifyListeners();
    for (final adapter in _adapters.values) {
      await adapter.reload();
    }
    loading = false;
    notifyListeners();
  }

  List<DataSource<RemoteExtension>> getRepoDataSources(
    RemoteExtensionRepo repo,
  ) {
    return _adapters.values
        .map((adapter) => adapter.getRepoDataSource(repo.data))
        .toList();
  }

  Future<RemoteExtensionRepo> getRepo(String url) async {
    for (final adapter in _adapters.values) {
      try {
        return await adapter.getRepo(url);
      } catch (e) {
        logger.e('Failed to get repo from $url', error: e);
      }
    }
    throw Exception('Failed to get repo from $url');
  }

  Future<void> install(String location) async {
    for (final adapter in _adapters.values) {
      try {
        await adapter.install(location);
        return;
      } catch (e) {
        logger.e('Failed to install extension from $location', error: e);
      }
    }
    throw Exception('Failed to install extension from $location');
  }

  Future<void> uninstall(Extension ext) async {
    final adapter = _adapters.values
        .where((adapter) => adapter._extensions.contains(ext))
        .firstOrNull;
    if (adapter == null) {
      return;
    }
    await adapter.uninstall(ext);
  }

  Future<SourcePath> source(EpisodePath ep, {rust.CancelToken? token}) async {
    final entry = ep.entry;
    final ext = entry.extension;
    if (ext == null) {
      throw Exception('Extension not found for id ${entry.boundExtensionId}');
    }
    return await ext.source(ep, token: token);
  }

  Extension? tryGetExtension(String id) {
    return getExtensions().where((e) => e.data.id == id).firstOrNull;
  }

  static Future<void> ensureInitialized() async {
    register<ExtensionService>(await ExtensionService().init());
  }
}
