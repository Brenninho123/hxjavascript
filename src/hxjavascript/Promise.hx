package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Ergonomic wrapper around native JavaScript Promises.
 *
 * Example:
 * ```haxe
 * var p = new Promise(function(resolve, reject) {
 *     resolve(42);
 * });
 * p.then(v -> trace("Result:", v))
 *  .catchError(e -> trace("Error:", e));
 *
 * // Fetch shorthand:
 * Promise.resolve("Hello!")
 *     .then(v -> trace(v));
 *
 * // Chain multiple:
 * Promise.all([Promise.resolve(1), Promise.resolve(2)])
 *     .then(results -> trace(results));
 * ```
 */
class Promise {
    var _promise:Dynamic;

    public function new(executor:Dynamic -> Dynamic -> Void) {
        _promise = untyped __js__("new Promise({0})", executor);
    }

    function _fromRaw(raw:Dynamic):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = raw;
        return p;
    }

    /** Creates an already-resolved Promise with the given value. */
    public static function resolve<T>(value:T):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = untyped __js__("Promise.resolve({0})", value);
        return p;
    }

    /** Creates an already-rejected Promise with the given reason. */
    public static function reject(reason:Dynamic):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = untyped __js__("Promise.reject({0})", reason);
        return p;
    }

    /**
     * Waits for all promises in the array to resolve.
     * Rejects as soon as any one of them rejects.
     */
    public static function all(promises:Array<Promise>):Promise {
        var raws = promises.map(p -> p._promise);
        var p = new Promise(function(_, _) {});
        p._promise = untyped __js__("Promise.all({0})", raws);
        return p;
    }

    /**
     * Resolves/rejects as soon as the first promise in the array settles.
     */
    public static function race(promises:Array<Promise>):Promise {
        var raws = promises.map(p -> p._promise);
        var p = new Promise(function(_, _) {});
        p._promise = untyped __js__("Promise.race({0})", raws);
        return p;
    }

    /** Chains a success callback. Returns a new `Promise`. */
    public function then(onFulfilled:Dynamic -> Void):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = untyped _promise.then(onFulfilled);
        return p;
    }

    /** Chains an error callback. Returns a new `Promise`. */
    public function catchError(onRejected:Dynamic -> Void):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = untyped _promise.catch(onRejected);
        return p;
    }

    /** Registers a callback that runs regardless of outcome. */
    public function finally(onFinally:Void -> Void):Promise {
        var p = new Promise(function(_, _) {});
        p._promise = untyped _promise.finally(onFinally);
        return p;
    }

    /** Returns the raw underlying JS Promise object. */
    public inline function unwrap():Dynamic {
        return _promise;
    }
}
