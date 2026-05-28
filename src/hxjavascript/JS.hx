package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Core utilities for executing and interacting with raw JavaScript at runtime.
 *
 * All methods are `inline` and compile down to zero-overhead JS expressions.
 *
 * Example:
 * ```haxe
 * var sum:Int = JS.eval("1 + 2 + 3");
 * JS.run("document.title = 'Hello from Haxe'");
 * trace(JS.typeof(42));        // "number"
 * trace(JS.exists("jQuery"));  // true / false
 * ```
 */
class JS {
    /**
     * Evaluates a JavaScript expression and returns the result cast to `T`.
     * Avoid passing untrusted strings — this calls `eval()` internally.
     */
    public static inline function eval<T>(code:String):T {
        return untyped __js__("eval({0})", code);
    }

    /**
     * Runs a JavaScript statement with no return value.
     * Uses `new Function(code)()` to avoid polluting the local scope.
     */
    public static inline function run(code:String):Void {
        untyped __js__("(new Function({0}))()", code);
    }

    /**
     * Returns the JavaScript `typeof` string for any value.
     * Possible values: "undefined", "boolean", "number", "string",
     * "bigint", "symbol", "function", "object".
     */
    public static inline function typeof(value:Dynamic):String {
        return untyped __js__("typeof {0}", value);
    }

    /**
     * Returns `true` if a variable with the given name exists on `window`
     * (or the global object in non-browser contexts).
     */
    public static inline function exists(name:String):Bool {
        return untyped __js__("typeof window[{0}] !== 'undefined'", name);
    }

    /**
     * Gets a property from the global `window` object by name.
     */
    public static inline function globalGet<T>(name:String):T {
        return untyped __js__("window[{0}]", name);
    }

    /**
     * Sets a property on the global `window` object by name.
     */
    public static inline function globalSet(name:String, value:Dynamic):Void {
        untyped __js__("window[{0}] = {1}", name, value);
    }

    /**
     * Parses a JSON string and returns the result as a `Dynamic` object.
     */
    public static inline function parseJSON(json:String):Dynamic {
        return untyped __js__("JSON.parse({0})", json);
    }

    /**
     * Serializes any value to a JSON string.
     */
    public static inline function stringifyJSON(value:Dynamic, ?indent:Int):String {
        return untyped __js__("JSON.stringify({0}, null, {1})", value, indent);
    }
}
