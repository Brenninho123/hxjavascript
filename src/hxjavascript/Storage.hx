package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Convenient typed wrapper around `localStorage` and `sessionStorage`.
 *
 * Example:
 * ```haxe
 * // localStorage
 * Storage.local.set("username", "Brenninho");
 * trace(Storage.local.get("username")); // "Brenninho"
 * Storage.local.remove("username");
 *
 * // sessionStorage
 * Storage.session.set("token", "abc123");
 * ```
 */
class StorageArea {
    var _store:Dynamic;

    public function new(store:Dynamic) {
        _store = store;
    }

    /** Stores a string value. */
    public inline function set(key:String, value:String):Void {
        untyped _store.setItem(key, value);
    }

    /** Retrieves a stored string, or `null` if not found. */
    public inline function get(key:String):Null<String> {
        return untyped _store.getItem(key);
    }

    /** Removes the item with the given key. */
    public inline function remove(key:String):Void {
        untyped _store.removeItem(key);
    }

    /** Clears all entries in this storage area. */
    public inline function clear():Void {
        untyped _store.clear();
    }

    /** Returns the number of stored entries. */
    public inline function length():Int {
        return untyped _store.length;
    }

    /** Returns the key at the given numeric index. */
    public inline function key(index:Int):Null<String> {
        return untyped _store.key(index);
    }

    /**
     * Stores an object serialized as JSON.
     * Retrieve it with `getObject`.
     */
    public inline function setObject(key:String, value:Dynamic):Void {
        untyped _store.setItem(key, __js__("JSON.stringify({0})", value));
    }

    /**
     * Retrieves and deserializes a JSON-stored object.
     * Returns `null` if the key does not exist.
     */
    public inline function getObject<T>(key:String):Null<T> {
        var raw:Null<String> = untyped _store.getItem(key);
        if (raw == null) return null;
        return untyped __js__("JSON.parse({0})", raw);
    }

    /** Returns all stored keys as an array. */
    public function keys():Array<String> {
        var result:Array<String> = [];
        var len:Int = untyped _store.length;
        for (i in 0...len)
            result.push(untyped _store.key(i));
        return result;
    }
}

class Storage {
    static var _local:StorageArea;
    static var _session:StorageArea;

    /** Access to `window.localStorage`. */
    public static var local(get, never):StorageArea;
    static function get_local():StorageArea {
        if (_local == null) _local = new StorageArea(untyped __js__("localStorage"));
        return _local;
    }

    /** Access to `window.sessionStorage`. */
    public static var session(get, never):StorageArea;
    static function get_session():StorageArea {
        if (_session == null) _session = new StorageArea(untyped __js__("sessionStorage"));
        return _session;
    }
}
