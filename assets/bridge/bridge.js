function __isPromise(value) {
    return Boolean(value && typeof value.then === 'function');
}
var __dbg = (...a) => sendMessage("__dbg", JSON.stringify(a))
var window = global = globalThis;
var __q = []
function __sendmsg(name, args) {
    //  __dbg("sendmsg",name,args)
    let p = new Promise((res) => {
        __q.push(res);
    });
    let id = __q.length - 1;
    sendMessage("mcall", JSON.stringify([name, id, args]));
    return p;
}
function __onmsg(id, rets) {
    //  __dbg("onmsg",id,rets)
    if (__q.length > id) {
        __q[id](rets);
        __q.splice(id, 1);
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
        __dbg("Warning no handler found by that name ", name, "known handlers are: ", ...__h.keys());
        return "null";
    }
}
var Bridge = {
    sendMessage: __sendmsg,
    setHandler: __setuphandler,
}