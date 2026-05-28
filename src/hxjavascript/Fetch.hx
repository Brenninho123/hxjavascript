package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Typed wrapper around the browser Fetch API.
 *
 * Example:
 * ```haxe
 * // Simple GET
 * Fetch.get("https://api.example.com/data")
 *     .then(r -> trace(r.status, r.text()))
 *     .catchError(e -> trace("Error:", e));
 *
 * // POST with JSON body
 * Fetch.post("https://api.example.com/save", { name: "Haxe" })
 *     .then(r -> trace("Saved!"))
 *     .catchError(e -> trace(e));
 * ```
 */
class FetchResponse {
    var _res:Dynamic;

    public var status(get, never):Int;
    public var ok(get, never):Bool;
    public var statusText(get, never):String;
    public var url(get, never):String;

    public function new(raw:Dynamic) { _res = raw; }

    function get_status():Int     return untyped _res.status;
    function get_ok():Bool        return untyped _res.ok;
    function get_statusText():String return untyped _res.statusText;
    function get_url():String     return untyped _res.url;

    /** Reads the body as plain text. Returns a `Promise` resolving to `String`. */
    public function text():Promise {
        var p = new Promise(function(_, _) {});
        p.unwrap(); // just allocate; we override below
        var raw = untyped _res.text();
        var wp = new Promise(function(_, _) {});
        untyped wp._promise = raw;
        return wp;
    }

    /** Reads and parses the body as JSON. Returns a `Promise` resolving to `Dynamic`. */
    public function json():Promise {
        var wp = new Promise(function(_, _) {});
        untyped wp._promise = untyped _res.json();
        return wp;
    }

    /** Returns the raw underlying Response object. */
    public inline function unwrap():Dynamic return _res;
}

class Fetch {
    /**
     * Performs a GET request to the given URL.
     * Returns a `Promise` that resolves to a `FetchResponse`.
     */
    public static function get(url:String, ?headers:Dynamic):Promise {
        return _fetch(url, "GET", null, headers);
    }

    /**
     * Performs a POST request with an optional JSON body.
     * Returns a `Promise` that resolves to a `FetchResponse`.
     */
    public static function post(url:String, ?body:Dynamic, ?headers:Dynamic):Promise {
        return _fetch(url, "POST", body, headers);
    }

    /**
     * Performs a PUT request with an optional JSON body.
     */
    public static function put(url:String, ?body:Dynamic, ?headers:Dynamic):Promise {
        return _fetch(url, "PUT", body, headers);
    }

    /**
     * Performs a DELETE request.
     */
    public static function delete(url:String, ?headers:Dynamic):Promise {
        return _fetch(url, "DELETE", null, headers);
    }

    /**
     * Low-level fetch with full options control.
     * @param url Target URL.
     * @param method HTTP method string.
     * @param body Optional request body (will be JSON-serialized if not a string).
     * @param headers Optional headers object.
     */
    public static function request(url:String, method:String, ?body:Dynamic, ?headers:Dynamic):Promise {
        return _fetch(url, method, body, headers);
    }

    static function _fetch(url:String, method:String, body:Dynamic, headers:Dynamic):Promise {
        var opts:Dynamic = untyped __js__("{}");
        untyped opts.method = method;

        var h:Dynamic = untyped __js__("{ 'Content-Type': 'application/json' }");
        if (headers != null) {
            var keys:Array<String> = untyped __js__("Object.keys({0})", headers);
            for (k in keys) untyped h[k] = untyped headers[k];
        }
        untyped opts.headers = h;

        if (body != null) {
            untyped opts.body = (untyped __js__("typeof {0} === 'string'", body))
                ? body
                : untyped __js__("JSON.stringify({0})", body);
        }

        var raw:Dynamic = untyped __js__("fetch({0}, {1})", url, opts);
        var mapped:Dynamic = untyped raw.then(function(r:Dynamic) {
            return untyped __js__("r"); // passthrough — wrapped below
        });

        // Wrap resolved value into FetchResponse
        var wrapped:Dynamic = untyped raw.then(function(r:Dynamic) {
            return r;
        });

        var wp = new Promise(function(_, _) {});
        untyped wp._promise = untyped raw.then(function(r:Dynamic) {
            return new FetchResponse(r);
        });
        return wp;
    }
}
