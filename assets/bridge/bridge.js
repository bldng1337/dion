function __isPromise(value) {
  return Boolean(value && typeof value.then === "function");
}
var __dbg = (...a) => sendMessage("__dbg", JSON.stringify(a));
var window = (global = globalThis);
var __queue = new Map();
function __findqueuename(name) {
  for (let i = 0; i < 1000; i++) {
    let n = name + "_" + i;
    if (!__queue.has(n)) {
      return n;
    }
  }
  __dbg(
    "Warning: could not find a unique queue name for ",
    name,
    "over 1000 unresolved calls to the function pending"
  );
  throw new Error(
    "[Bridge]: Could not find a unique queue name for " +
      name +
      "over 1000 unresolved calls to the function pending"
  );
}

function __sendmsg(name, args) {
//   __dbg("sendmsg", name, args);
  let id = __findqueuename(name);
  __queue.set(id, 1); //reserve the name
  let p = new Promise((res) => {
    __queue.set(id, res);
  });
  sendMessage("mcall", JSON.stringify([name, id, args]));
  return p;
}
function __onmsg(id, rets) {
//   __dbg("onmsg", id, rets);
  if (__queue.has(id)) {
    __queue.get(id)(rets);
    __queue.delete(id);
  }else{
    __dbg("Warning: no promise found for id ", id);
  }
}
var __h = new Map();
function __setuphandler(name, func) {
  // __dbg("Registering "+name)
  __h.set(name, func);
}
async function __callhandler(name, args) {
  if (__h.has(name)) {
    let a = __h.get(name)(args);
    if (__isPromise(a)) {
      a = await a;
    }
    return JSON.stringify(a);
  } else {
    __dbg(
      "Warning no handler found by that name ",
      name,
      "known handlers are: ",
      ...__h.keys()
    );
    return "null";
  }
}
var Bridge = {
  sendMessage: __sendmsg,
  setHandler: __setuphandler,
};
