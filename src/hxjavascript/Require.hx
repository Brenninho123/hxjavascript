package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Dynamic module loader for CommonJS (`require`) and ESM (`import()`) environments.
 *
 * CommonJS example (Node.js / bundlers):
 * ```haxe
 * var fs = Require.module("fs");
 * var data:String = fs.readFileSync("file.txt", "utf8");
 * ```
 *
 * ESM async example:
 * ```haxe
 * Require.importModule("./myModule.js", mod -> {
 *     mod.default.doSomething();
 * });
 * ```
 */
class Require {
    /**
     * Synchronously loads a CommonJS module via `require()`.
     * Only available in Node.js or bundler environments — not in bare browsers.
     * Returns the module exports as a `JSObject`.
     */
    public static inline function module(name:String):JSObject {
        return JSObject.from(untyped __js__("require({0})", name));
    }

    /**
     * Asynchronously imports an ES module via the dynamic `import()` expression.
     * Works in modern browsers and Node.js 12+.
     *
     * @param path Module path or URL.
     * @param onLoaded Callback receiving the module namespace as a `JSObject`.
     * @param ?onError Optional error callback.
     */
    public static function importModule(
        path:String,
        onLoaded:JSObject -> Void,
        ?onError:Dynamic -> Void
    ):Void {
        var promise:Dynamic = untyped __js__("import({0})", path);
        untyped promise.then(function(mod:Dynamic) {
            onLoaded(JSObject.from(mod));
        });
        if (onError != null)
            untyped promise.catch(onError);
    }

    /**
     * Returns `true` if `require` is available in the current environment.
     */
    public static inline function isAvailable():Bool {
        return untyped __js__("typeof require === 'function'");
    }
}
