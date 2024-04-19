import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/Source.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/network_manager.dart';
import 'package:flutter_js/flutter_js.dart';
import "package:async_locks/async_locks.dart";
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
      this.url, this.icon, this.minApiVersion, this.version, this.name);

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
  latest("latest"),
  updated("updated"),
  popular("popular");

  const SortMode(this.val);
  final String val;
}

class JSExt {
  late final JavascriptRuntime runtime;
  late final Bridge bridge;

  JSExt(String src) {
    runtime = getJavascriptRuntime();
    bridge = Bridge(runtime);

    bridge.register("log", (a) {
      print("[JS] $a");
    });

    bridge.register("request", (a) async {
      try {
        final url = a[0];
        final options = a[1];
        switch ((options["method"] as String).toLowerCase()) {
          case "get":
            final ret = await NetworkManager()
                .dio
                .get(url, options: dio.Options(headers: options["headers"]));
            return {"headers": ret.headers.map, "body": (ret.data is String)?ret.data:json.encode(ret.data)};
          case "post":
            final ret = await NetworkManager()
                  .dio.post(url,data: options["data"],options: dio.Options(headers: options["headers"]));
            return {"headers": ret.headers.map, "body": (ret.data is String)?ret.data:json.encode(ret.data)};
        }
      } catch (e) {
        return {"error": true, "reason": e.toString()};
      }
      return {"error": true, "reason": "end of method! wrong option.method?"};
    });
    bridge.register("getCookies", (a) async {
      final url = a[0] as String;
      var cookie=await NetworkManager().getCookies(url);
      return cookie.map((e) => {"name":e.name,"value":e.value}).toList();
    });
    var a = runtime.evaluate(
      src,
    );
    if (a.isError) {
      print(a.stringResult);
      return;
    }

    runtime.evaluate("""
    var extension=new ext.default();
    extension.load();
    """
        .trim());
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
    configpath = path.twin(".config.json");
  }

  Future<Extension> init() async {
    if(!await configpath.exists()){
      await configpath.writeAsString("{}");
    }
    String filecontent=await configpath.readAsString();
    if(filecontent.isEmpty){
      filecontent="{}";
    }
    dynamic js=json.decode(filecontent);
    settings=js["settings"]??{};
    data=ExtensionData.fromJson(json.decode((await extensionpath.readAsString()).substring(2).split("\n")[0]));
    await setenabled(js["enabled"]??false);
    return this;
  }

  dispose(){
    enabled=false;
    engine?.dispose();
    engine=null;
  }

  Future<void> setenabled(bool nenabled) async {
    if(!enabled&&nenabled){
      enabled=true;
      engine=JSExt(await extensionpath.readAsString());
      engine!.bridge.register("registerSetting",(data) => settings.putIfAbsent(data["name"], () => data));
      engine!.bridge.register("getSetting", (key)=> settings[key]);
    }else if(enabled&&!nenabled){
      enabled=false;
      engine?.dispose();
      engine=null;
    }
    save();
  }

  setsettings(String key,dynamic value) async {
    settings[key]=value;
    save();
  }

  save(){
    configpath.writeAsString(json.encode({"enabled":enabled,"settings":settings}));
  }

  Future<List<Entry>> browse(int page, SortMode sort) async {
    if(engine==null){
      return [];
    }
    var ret = (await engine!.bridge.invoke("browse", {"page": page, "sort": sort.val}))
        as List?;
    if (ret==null||ret.isEmpty) {
      return [];
    }
    return ret.map((e) => Entry.fromJson(e, this)).toList();
  }

  Future<List<Entry>> search(int page, String filter) async {
    if(engine==null){
      return [];
    }
    var ret = (await engine!.bridge.invoke("search", {"page": page, "filter": filter}))
        as List?;
    if (ret==null||ret.isEmpty) {
      return [];
    }
    return ret.map((e) => Entry.fromJson(e, this)).toList();
  }

  Future<EntryDetail?> detail(String url) async {
    if(engine==null){
      return null;
    }
    var ret = await engine!.bridge.invoke("detail", {"url": url});
    if (ret == null) return null;
    return EntryDetail.fromJson(ret, this);
  }

  Future<Source?> source(Episode ep, EntryDetail entry) async {
    if(engine==null){
      return null;
    }
    var ret = await engine!.bridge.invoke("source", {"url": ep.url});
    if (ret == null) return null;
    return Source.fromJson(ret, entry, ep);
  }
  
  
}

class Bridge {
  Map<String, Function> methods = {};
  JavascriptRuntime runtime;
  Bridge(this.runtime) {
    runtime.onMessage("__dbg", print);
    runtime.onMessage("mcall", _invoke);
    runtime.evaluate(BRIDGE);
    runtime.enableHandlePromises();
  }
  final lock = Lock();

  register(String name, Function handler) {
    methods[name] = handler;
  }

  Future<dynamic> invoke(String event, dynamic args) async {
    await lock.acquire();
    var a;
    try{
      JsEvalResult jsres = await runtime.handlePromise(
        runtime.evaluate("__callhandler('$event',${json.encode(args)})"),
      );
      if (!jsres.isError) {
        a=json.decode(jsres.stringResult);
      }
    }catch (e){
      print("Error executing JS function: $e");
    }
    lock.release();
    return a;
  }

  _invoke(args) async {
    if (!methods.containsKey(args[0])) {
      print("Handler not registered");
      return;
    }
    dynamic ret = methods[args[0]]!(args[2]);
    if (ret is Future) {
      ret = await ret;
    }
    runtime.evaluate("__onmsg(${args[1]},${json.encode(ret)})");
    runtime.executePendingJob();
  }
}

const BRIDGE = '''
function __isPromise(value) {
    return Boolean(value && typeof value.then === 'function');
  }
  var __dbg=(...a)=>sendMessage("__dbg",JSON.stringify(a))
  var window = global = globalThis;
  var __q=[]
  function __sendmsg(name,...args){
    //  __dbg("sendmsg",name,args)
    let p=new Promise((res)=>{
      __q.push(res);
    });
    let id=__q.length-1;
    sendMessage("mcall",JSON.stringify([name,id,args]));
    return p;
  }
  function __onmsg(id,rets){
    //  __dbg("onmsg",id,rets)
    if(__q.length>id){
      __q[id](rets);
      __q.splice(id,1);
    }
  }
  var __h=new Map();
  function __setuphandler(name,func){
      // __dbg("Registering "+name)
      __h.set(name,func);
  }
  async function __callhandler(name,args) {
    if(__h.has(name)){
        let a=__h.get(name)(args);
        if(__isPromise(a)){
            a=await a;
        }
      return JSON.stringify(a);
    }else{
      __dbg("Warning no handler found by that name ",name,"known handlers are: ",...__h.keys());
      return "null";
    }
  }
  var Bridge={
      sendMessage:__sendmsg,
      setHandler:__setuphandler,
  }
''';
