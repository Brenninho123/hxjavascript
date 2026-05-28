# hxjavascript

**Haxe × JavaScript** — A Haxe library for ergonomic JavaScript interop.

Bridges the gap between Haxe's type system and the JavaScript runtime with zero-overhead wrappers for eval, dynamic objects, Web Workers, Fetch API, LocalStorage, CommonJS/ESM modules, Promises, and compile-time macros.

---

## Installation

### From haxelib (once published)

```sh
haxelib install hxjavascript
```

### From Git (development)

```sh
haxelib git hxjavascript https://github.com/Brenninho123/hxjavascript
```

Then add to your `build.hxml`:

```hxml
-lib hxjavascript
```

> ⚠️ This library **only works on the JavaScript target** (`-js`).
> All classes are guarded with `#if !js #error #end`.

---

## Modules

### `hxjavascript.JS` — Core JS utilities

```haxe
import hxjavascript.JS;

var sum:Int = JS.eval("1 + 2 + 3");
JS.run("document.title = 'Hello from Haxe'");
trace(JS.typeof(42));            // "number"
trace(JS.exists("jQuery"));     // true / false
JS.globalSet("myVar", 99);
trace(JS.globalGet("myVar"));   // 99
trace(JS.stringifyJSON({ a: 1 }, 2));
```

---

### `hxjavascript.JSObject` — Dynamic typed object wrapper

```haxe
import hxjavascript.JSObject;

var obj = JSObject.from({ name: "Haxe", version: 4 });
trace(obj.get("name"));           // "Haxe"
obj.set("version", 5);
trace(obj.has("name"));           // true
trace(obj.keys());                // ["name", "version"]
trace(obj.call("toString", []));  // "[object Object]"
trace(obj.toJSON(2));
```

---

### `hxjavascript.Worker` — Web Workers

```haxe
import hxjavascript.Worker;

var w = new Worker("worker.js");
w.onMessage(msg -> trace("Received:", msg.data));
w.onError(err -> trace("Error:", err.message));
w.post({ action: "compute", value: 42 });
// later...
w.terminate();
```

---

### `hxjavascript.Promise` — JS Promises

```haxe
import hxjavascript.Promise;

Promise.resolve(42)
    .then(v -> trace("Value:", v))
    .catchError(e -> trace("Error:", e));

Promise.all([Promise.resolve(1), Promise.resolve(2)])
    .then(results -> trace(results));
```

---

### `hxjavascript.Fetch` — Fetch API

```haxe
import hxjavascript.Fetch;

Fetch.get("https://api.example.com/data")
    .then(r -> trace(r.status))
    .catchError(e -> trace("Network error:", e));

Fetch.post("https://api.example.com/save", { name: "Haxe" })
    .then(r -> trace("Saved, status:", r.status));
```

---

### `hxjavascript.Storage` — localStorage / sessionStorage

```haxe
import hxjavascript.Storage;

Storage.local.set("username", "Brenninho");
trace(Storage.local.get("username"));  // "Brenninho"

Storage.local.setObject("config", { theme: "dark", lang: "pt" });
var cfg = Storage.local.getObject("config");
trace(cfg.theme); // "dark"

Storage.session.set("token", "abc123");
Storage.local.remove("username");
Storage.local.clear();
```

---

### `hxjavascript.Require` — CommonJS / ESM modules

```haxe
import hxjavascript.Require;

// CommonJS (Node.js / bundlers)
if (Require.isAvailable()) {
    var fs = Require.module("fs");
    trace(fs.get("existsSync"));
}

// ESM async import (modern browsers / Node 12+)
Require.importModule("./utils.js", mod -> {
    mod.get("default").doSomething();
}, err -> trace("Import failed:", err));
```

---

### `hxjavascript.macro.JSMacro` — Build macros

Auto-generates typed property accessors for `@jsProperty` fields:

```haxe
@:build(hxjavascript.macro.JSMacro.buildExtern())
class MyLib {
    @jsProperty public static var version:String;
}

trace(MyLib.version); // reads `version` from JS global scope
```

---

## Compatibility

| Feature         | Browser | Node.js |
|-----------------|:-------:|:-------:|
| `JS`            | ✅      | ✅      |
| `JSObject`      | ✅      | ✅      |
| `Promise`       | ✅      | ✅      |
| `Fetch`         | ✅      | ✅ (18+)|
| `Worker`        | ✅      | ✅ (v10+)|
| `Storage`       | ✅      | ❌      |
| `Require`       | ❌ (bare)| ✅     |

---

## Requirements

- **Haxe** 4.2+
- **Target**: `-js` only

---

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

## Author

[Brenninho123](https://github.com/Brenninho123)
