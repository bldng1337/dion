import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async_locks/async_locks.dart';
import 'package:dio/dio.dart' as dio;
import 'package:dionysos/Source.dart';
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/network_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:quiver/collection.dart';

class ExtensionData {
  final String repo;
  final String? giturl;
  final String name;
  final String? version;
  final String? desc;
  final String? author;
  final String? license;
  final List<String>? tags;
  final bool? nsfw;
  final List<String>? lang;
  final String? url;
  final String? icon;
  final List<MediaType>? type;

  ExtensionData(
    this.repo,
    this.name,
    this.version,
    this.desc,
    this.author,
    this.license,
    this.tags,
    this.nsfw,
    this.lang,
    this.url,
    this.giturl,
    this.icon,
    this.type,
  );

  factory ExtensionData.fromJson(Map<String, dynamic> json) {
    return ExtensionData(
      json['repo'] as String,
      json['name'] as String,
      json['version'] as String?,
      json['desc'] as String?,
      json['author'] as String?,
      json['license'] as String?,
      (json['tags'] as List<dynamic>?)?.cast<String>(),
      (json['nsfw'] as bool?) ?? false,
      (json['lang'] as List<dynamic>?)?.cast<String>(),
      json['url'] as String?,
      json['giturl'] as String?,
      json['icon'] as String?,
      (json['type'] as List<dynamic>?)
          ?.cast<String>()
          .map((name) => getMediaType(name))
          .toList()
          .cast<MediaType>(),
    );
  }
}

enum SortMode {
  latest('latest'),
  updated('updated'),
  popular('popular');

  const SortMode(this.val);
  final String val;
}

class JSExt {
  late final JavascriptRuntime runtime;
  late final Bridge bridge;

  JSExt(String src, Function(Bridge bridge) extensionregister) {
    runtime = getJavascriptRuntime();
    bridge = Bridge(runtime);

    extensionregister(bridge);

    bridge.register('log', (a) {
      if (kDebugMode) {
        //TODO: Good logging framework
        print('[JS] $a');
      }
    });

    bridge.register('request', (a) async {
      try {
        final url = a['url'];
        final options = a['options'];
        switch ((options['method'] as String).toLowerCase()) {
          case 'get':
            final ret = await NetworkManager().dio.get(
                  url as String,
                  options: dio.Options(
                    headers: options['headers'] as Map<String, dynamic>,
                  ),
                );
            return {
              'headers': ret.headers.map,
              'body': (ret.data is String) ? ret.data : json.encode(ret.data),
            };
          case 'post':
            final ret = await NetworkManager().dio.post(
                  url as String,
                  data: options['data'],
                  options: dio.Options(
                    headers: options['headers'] as Map<String, dynamic>,
                  ),
                );
            return {
              'headers': ret.headers.map,
              'body': (ret.data is String) ? ret.data : json.encode(ret.data),
            };
        }
      } catch (e) {
        return {'error': true, 'reason': 'Error executing request: $e'};
      }
      return {'error': true, 'reason': 'end of method! wrong option.method?'};
    });
    bridge.register('getCookies', (a) async {
      final url = a[0] as String;
      final cookie = await NetworkManager().getCookies(url);
      return cookie.map((e) => {'name': e.name, 'value': e.value}).toList();
    });
    final a = runtime.evaluate(
      src,
    );
    if (a.isError) {
      return;
    }

    runtime.evaluate(
      '''
    var extension=new ext();
    extension.load();
    '''
          .trim(),
    );
  }

  void dispose() {
    runtime.dispose();
  }
}

LruMap<String, EntryDetail> extensioncache = LruMap(maximumSize: 10);

class Extension {
  JSExt? engine;

  ExtensionData? data;

  late final File extensionpath;
  late final File configpath;

  Map<String, dynamic> settings = {};
  bool enabled = false;

  String get indentifier {
    return "${data!.name}@${data!.giturl ?? ""}";
  }

  bool keycompat(String e) {
    return e == indentifier;
  }

  bool entrycompat(Entry e) {
    return e.extname == indentifier;
  }

  Extension(File path) {
    extensionpath = path;
    configpath = path.twin('.config.json');
  }

  Future<Extension> init() async {
    if (!await configpath.exists()) {
      await configpath.writeAsString('{}');
    }
    String filecontent = await configpath.readAsString();
    if (filecontent.isEmpty) {
      filecontent = '{}';
    }
    final js = json.decode(filecontent) as Map<String, dynamic>;
    settings = (js['settings'] as Map<String, dynamic>?) ?? {};
    final meta =
        (await extensionpath.readAsString()).substring(2).split('\n')[0];
    data = ExtensionData.fromJson(json.decode(meta) as Map<String, dynamic>);
    await setenabled((js['enabled'] as bool?) ?? false);
    return this;
  }

  void dispose() {
    enabled = false;
    engine?.dispose();
    engine = null;
  }

  Future<void> setenabled(bool nenabled) async {
    if (!enabled && nenabled) {
      engine = JSExt(await extensionpath.readAsString(), (bridge) {
        bridge.register('registerSetting', (data) {
          // settings.update(key, update)
          var value = data['def'];
          if (settings.containsKey(data['id'] as String) &&
              settings[data['id'] as String] is Map<String, dynamic>) {
            value = settings[data['id'] as String]['value'];
          }
          settings[data['id'] as String] = data;
          print("Registered ${data['id']} with value $value");
          settings[data['id'] as String]!['value'] = value;
        });
        bridge.register('getSetting', (key) => settings[key['id']]['value']);
        bridge.register(
            'setUI', (data) => settings[data['id']]['ui'] = data['ui']);
      });
      enabled = true;
      // engine!.bridge.register('registerSetting',(data) => settings.putIfAbsent(data['name'] as String, () => data));
      // engine!.bridge.register('getSetting', (key)=> settings[key]); TODO: Settings system
    } else if (enabled && !nenabled) {
      enabled = false;
      engine?.dispose();
      engine = null;
    }
    save();
  }

  void setsettings(String key, dynamic value) {
    settings[key]['value'] = value;
    save();
  }

  Future<void> save() async {
    await configpath
        .writeAsString(json.encode({'enabled': enabled, 'settings': settings}));
  }

  Future<List<Entry>> browse(int page, SortMode sort) async {
    if (engine == null||!enabled) {
      return [];
    }
    final ret = (await engine!.bridge
        .invoke('browse', {'page': page, 'sort': sort.val})) as List?;
    if (ret == null || ret.isEmpty) {
      return [];
    }
    return ret
        .map((e) => Entry.fromJson(e as Map<String, dynamic>, this))
        .toList();
  }

  Future<List<Entry>> search(int page, String filter) async {
    if (engine == null||!enabled) {
      return [];
    }
    final ret = (await engine!.bridge
        .invoke('search', {'page': page, 'filter': filter})) as List?;
    if (ret == null || ret.isEmpty) {
      return [];
    }
    return ret
        .map((e) => Entry.fromJson(e as Map<String, dynamic>, this))
        .toList();
  }

  Future<EntryDetail?> detail(String url, {bool force = false}) async {
    if (extensioncache.containsKey(url)&&!force) {
      return extensioncache[url];
    }
    if (engine == null||!enabled) {
      return null;
    }
    final ret = await engine!.bridge.invoke('detail', {'entryid': url});
    if (ret == null) return null;
    final ent = EntryDetail.fromJson(ret as Map<String, dynamic>, this);
    extensioncache.putIfAbsent(url, () => ent);
    return ent;
  }

  Future<Source?> source(Episode ep, EntryDetail entry) async {
    if (engine == null||!enabled) {
      return null;
    }
    final ret = await engine!.bridge.invoke('source', {'epid': ep.url});
    if (ret == null) return null;
    return Source.fromJson(ret as Map<String, dynamic>, entry, ep);
  }
}

class Bridge {
  Map<String, Function> methods = {};
  JavascriptRuntime runtime;

  Bridge(this.runtime) {
    // ignore: avoid_print
    runtime.onMessage('__dbg', (a) {
      if ((a as List<dynamic>)
              .cast<String>()
              .firstWhereOrNull((a) => a.toLowerCase().contains('warning')) !=
          null) {
        debugPrintStack(stackTrace: StackTrace.current);
      }
      print(a);
    });
    runtime.onMessage('mcall', _invoke);

    runtime.evaluate(bridge!);
    runtime.enableHandlePromises();
  }
  final lock = Lock();

  void register(String name, Function handler) {
    methods[name] = handler;
  }

  Future<dynamic> invoke(String event, dynamic args) async {
    await lock.acquire();
    dynamic a;
    try {
      final JsEvalResult jsres = await runtime.handlePromise(
        runtime.evaluate("__callhandler('$event',${json.encode(args)})"),
      );
      if (!jsres.isError) {
        a = json.decode(jsres.stringResult);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error executing JS function: $e');
      }
    }
    lock.release();
    return a;
  }

  Future<void> _invoke(args) async {
    if (!methods.containsKey(args[0])) {
      if (kDebugMode) {
        print('Handler not registered ${args[0]}');
      }
      return;
    }
    dynamic ret;
    try {
      ret = methods[args[0]]!(args[2]);
      if (ret is Future) {
        ret = await ret;
      }
    } catch (e) {
      ret = {'error': true, 'reason': e.toString()};
    }
    runtime.evaluate('__onmsg(${args[1]},${json.encode(ret)})');
    runtime.executePendingJob();
  }
}

String? bridge;

Future<void> ensureJSBridgeInitialised() async {
  bridge = await rootBundle.loadString('assets/bridge/bridge.js');
}
