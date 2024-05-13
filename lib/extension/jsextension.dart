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

class ExtensionData {
  final String name;
  final MediaType type;
  final String? desc;
  final String? author;
  final String? authorurl;
  final String? giturl;
  final String? url;
  final String? icon;
  final double? minApiVersion;
  final double? version;

  ExtensionData(this.type, this.desc, this.author, this.authorurl, this.giturl,
      this.url, this.icon, this.minApiVersion, this.version, this.name,);

  factory ExtensionData.fromJson(Map<String, dynamic> json) {
    return ExtensionData(
      getMediaType(json['type'] as String),
      json['desc'] as String?,
      json['author'] as String?,
      json['authorurl'] as String?,
      json['giturl'] as String?,
      json['url'] as String?,
      json['icon'] as String?,
      (json['minimum_api_version'] as num?)?.toDouble(),
      (json['version'] as num?)?.toDouble(),
      json['name'] as String,
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

  JSExt(String src) {
    runtime = getJavascriptRuntime();
    bridge = Bridge(runtime);

    bridge.register('log', (a) {
      if (kDebugMode) {//TODO: Good logging framework
        print('[JS] $a');
      }
    });

    bridge.register('request', (a) async {
      try {
        final url = a[0];
        final options = a[1];
        switch ((options['method'] as String).toLowerCase()) {
          case 'get':
            final ret = await NetworkManager()
                .dio
                .get(url as String, options: dio.Options(headers: options['headers'] as Map<String, dynamic>));
            return {'headers': ret.headers.map, 'body': (ret.data is String)?ret.data:json.encode(ret.data)};
          case 'post':
            final ret = await NetworkManager()
                  .dio.post(url as String,data: options['data'],options: dio.Options(headers: options['headers'] as Map<String, dynamic>));
            return {'headers': ret.headers.map, 'body': (ret.data is String)?ret.data:json.encode(ret.data)};
        }
      } catch (e) {
        return {'error': true, 'reason': e.toString()};
      }
      return {'error': true, 'reason': 'end of method! wrong option.method?'};
    });
    bridge.register('getCookies', (a) async {
      final url = a[0] as String;
      final cookie=await NetworkManager().getCookies(url);
      return cookie.map((e) => {'name':e.name,'value':e.value}).toList();
    });
    final a = runtime.evaluate(
      src,
    );
    if (a.isError) {
      return;
    }

    runtime.evaluate('''
    var extension=new ext.default();
    extension.load();
    '''
        .trim(),);
  }
  
  void dispose() {
    runtime.dispose();
  }
}

class Extension {
  JSExt? engine;
  ExtensionData? data;

  late final File extensionpath;
  late final File configpath;

  Map<String,dynamic> settings = {};
  bool enabled = false;

  String get indentifier {
    return "${data!.name}@${data!.giturl ?? ""}";
  }
  bool keycompat(String e){
    return e==indentifier;
  }
  bool entrycompat(Entry e) {
    return e.extname == indentifier;
  }

  Extension(File path) {
    extensionpath = path;
    configpath = path.twin('.config.json');
  }

  Future<Extension> init() async {
    if(!await configpath.exists()){
      await configpath.writeAsString('{}');
    }
    String filecontent=await configpath.readAsString();
    if(filecontent.isEmpty){
      filecontent='{}';
    }
    final js=json.decode(filecontent) as Map<String,dynamic>;
    settings=(js['settings'] as Map<String,dynamic>?)??{};
    data=ExtensionData.fromJson(json.decode((await extensionpath.readAsString()).substring(2).split('\n')[0]) as Map<String, dynamic>);
    await setenabled((js['enabled'] as bool?)??false);
    return this;
  }

  void dispose(){
    enabled=false;
    engine?.dispose();
    engine=null;
  }

  Future<void> setenabled(bool nenabled) async {
    if(!enabled&&nenabled){
      enabled=true;
      engine=JSExt(await extensionpath.readAsString());
      // engine!.bridge.register('registerSetting',(data) => settings.putIfAbsent(data['name'] as String, () => data));
      // engine!.bridge.register('getSetting', (key)=> settings[key]); TODO: Settings system
    }else if(enabled&&!nenabled){
      enabled=false;
      engine?.dispose();
      engine=null;
    }
    save();
  }

  Future<void> setsettings(String key,dynamic value) async {
    settings[key]=value;
    save();
  }

  void save(){
    configpath.writeAsString(json.encode({'enabled':enabled,'settings':settings}));
  }

  Future<List<Entry>> browse(int page, SortMode sort) async {
    if(engine==null){
      return [];
    }
    final ret = (await engine!.bridge.invoke('browse', {'page': page, 'sort': sort.val}))
        as List?;
    if (ret==null||ret.isEmpty) {
      return [];
    }
    return ret.map((e) => Entry.fromJson(e as Map<String, dynamic>, this)).toList();
  }

  Future<List<Entry>> search(int page, String filter) async {
    if(engine==null){
      return [];
    }
    final ret = (await engine!.bridge.invoke('search', {'page': page, 'filter': filter}))
        as List?;
    if (ret==null||ret.isEmpty) {
      return [];
    }
    return ret.map((e) => Entry.fromJson(e as Map<String, dynamic>, this)).toList();
  }

  Future<EntryDetail?> detail(String url) async {
    if(engine==null){
      return null;
    }
    final ret = await engine!.bridge.invoke('detail', {'url': url});
    if (ret == null) return null;
    return EntryDetail.fromJson(ret as Map<String, dynamic>, this);
  }

  Future<Source?> source(Episode ep, EntryDetail entry) async {
    if(engine==null){
      return null;
    }
    final ret = await engine!.bridge.invoke('source', {'url': ep.url});
    if (ret == null) return null;
    return Source.fromJson(ret as Map<String, dynamic>, entry, ep);
  }
  
  
}

class Bridge {
  Map<String, Function> methods = {};
  JavascriptRuntime runtime;
  Bridge(this.runtime) {
    // ignore: avoid_print
    runtime.onMessage('__dbg', print);
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
    try{
      final JsEvalResult jsres = await runtime.handlePromise(
        runtime.evaluate("__callhandler('$event',${json.encode(args)})"),
      );
      if (!jsres.isError) {
        a=json.decode(jsres.stringResult);
      }
    }catch (e){
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
        print('Handler not registered');
      }
      return;
    }
    dynamic ret;
    try{
      ret = methods[args[0]]!(args[2]);
      if (ret is Future) {
        ret = await ret;
      }
    }catch(e){
      ret={'error':true,'reason':e.toString()};
    }
    runtime.evaluate('__onmsg(${args[1]},${json.encode(ret)})');
    runtime.executePendingJob();
  }
}

String? bridge;

Future<void> ensureJSBridgeInitialised()async {
  bridge=await rootBundle.loadString('assets/bridge/bridge.js');
}
