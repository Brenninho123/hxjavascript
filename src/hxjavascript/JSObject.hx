package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * A lightweight typed wrapper around any JavaScript object.
 *
 * Provides safe `get`, `set`, `call`, `has`, and `delete` operations
 * without losing the underlying reference.
 *
 * Example:
 * ```haxe
 * var obj = JSObject.from({ name: "Haxe", version: 4 });
 * trace(obj.get("name"));          // "Haxe"
 * obj.set("version", 5);
 * trace(obj.call("toString", [])); // "[object Object]"
 * ```
 */
class JSObject {
    var _ref:Dynamic;

    public function new(ref:Dynamic) {
        _ref = ref;
    }

    /** Wraps an existing JS object. */
    public static inline function from(obj:Dynamic):JSObject {
        return new JSObject(obj);
    }

    /** Creates a new empty JS object `{}`. */
    public static inline function empty():JSObject {
        return new JSObject(untyped __js__("{}"));
    }

    /** Creates a new JS array `[]`. */
    public static inline function array():JSObject {
        return new JSObject(untyped __js__("[]"));
    }

    /** Gets a property value by name. */
    public inline function get<T>(key:String):T {
        return untyped _ref[key];
    }

    /** Sets a property value by name. */
    public inline function set(key:String, value:Dynamic):Void {
        untyped _ref[key] = value;
    }

    /** Returns `true` if the object has the given own property. */
    public inline function has(key:String):Bool {
        return untyped __js__("{0}.hasOwnProperty({1})", _ref, key);
    }

    /** Deletes a property from the object. */
    public inline function delete(key:String):Bool {
        return untyped __js__("delete {0}[{1}]", _ref, key);
    }

    /**
     * Calls a method on the object with the given arguments array.
     * Returns the result as `T`.
     */
    public inline function call<T>(method:String, args:Array<Dynamic>):T {
        return untyped __js__("{0}[{1}].apply({0}, {2})", _ref, method, args);
    }

    /** Returns all own enumerable property keys. */
    public inline function keys():Array<String> {
        return untyped __js__("Object.keys({0})", _ref);
    }

    /** Returns all own enumerable values. */
    public inline function values():Array<Dynamic> {
        return untyped __js__("Object.values({0})", _ref);
    }

    /** Returns the raw underlying JS reference. */
    public inline function unwrap():Dynamic {
        return _ref;
    }

    /** Serializes the object to a JSON string. */
    public inline function toJSON(?indent:Int):String {
        return untyped __js__("JSON.stringify({0}, null, {1})", _ref, indent);
    }
}
