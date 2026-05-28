import hxjavascript.JS;
import hxjavascript.JSObject;
import hxjavascript.Promise;
import hxjavascript.Storage;
import hxjavascript.Fetch;
import hxjavascript.Require;

class Test {
    static function main() {
        // --- JS ---
        trace("=== JS ===");
        var sum:Int = JS.eval("1 + 2 + 3");
        trace("eval 1+2+3 =", sum);
        trace("typeof 42 =", JS.typeof(42));
        trace("typeof 'hi' =", JS.typeof("hi"));
        JS.globalSet("hxTest", true);
        trace("exists hxTest =", JS.exists("hxTest"));
        trace("globalGet hxTest =", JS.globalGet("hxTest"));
        trace("stringifyJSON =", JS.stringifyJSON({ a: 1, b: [2, 3] }, 2));

        // --- JSObject ---
        trace("\n=== JSObject ===");
        var obj = JSObject.from({ name: "Haxe", version: 4 });
        trace("get name =", obj.get("name"));
        obj.set("version", 5);
        trace("get version after set =", obj.get("version"));
        trace("has name =", obj.has("name"));
        trace("has missing =", obj.has("missing"));
        trace("keys =", obj.keys());
        trace("toJSON =", obj.toJSON());

        // --- Promise ---
        trace("\n=== Promise ===");
        Promise.resolve("Hello from Promise!")
            .then(v -> trace("Promise resolved:", v))
            .catchError(e -> trace("Promise error:", e));

        Promise.all([Promise.resolve(10), Promise.resolve(20)])
            .then(results -> trace("Promise.all results:", results));

        // --- Storage ---
        trace("\n=== Storage ===");
        Storage.local.set("username", "Brenninho");
        trace("local.get username =", Storage.local.get("username"));
        Storage.local.setObject("config", { theme: "dark", lang: "pt-BR" });
        var cfg:Dynamic = Storage.local.getObject("config");
        trace("local config.theme =", cfg.theme);
        trace("local keys =", Storage.local.keys());
        Storage.local.remove("username");
        trace("after remove, username =", Storage.local.get("username"));

        // --- Fetch ---
        trace("\n=== Fetch ===");
        Fetch.get("https://jsonplaceholder.typicode.com/todos/1")
            .then(r -> {
                trace("Fetch status =", r.status);
                trace("Fetch ok =", r.ok);
                return r.json();
            })
            .then(data -> trace("Fetch body.title =", data.title))
            .catchError(e -> trace("Fetch error:", e));

        // --- Require (Node.js only) ---
        trace("\n=== Require ===");
        trace("require available =", Require.isAvailable());
        if (Require.isAvailable()) {
            var path = Require.module("path");
            trace("path.join =", path.call("join", ["foo", "bar", "baz.txt"]));
        }
    }
}
