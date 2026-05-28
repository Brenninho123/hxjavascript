package hxjavascript;

#if !js
#error "hxjavascript only works on the JavaScript target"
#end

/**
 * Ergonomic wrapper around the browser Web Workers API.
 *
 * Example:
 * ```haxe
 * var w = new Worker("worker.js");
 * w.onMessage(msg -> trace("Received:", msg.data));
 * w.onError(err -> trace("Error:", err.message));
 * w.post({ action: "start", value: 42 });
 * // ...
 * w.terminate();
 * ```
 */
class Worker {
    var _worker:Dynamic;

    /**
     * Creates a new Web Worker from the given script URL.
     * @param url Path to the worker JS file.
     * @param options Optional worker options object (e.g. `{ type: "module" }`).
     */
    public function new(url:String, ?options:Dynamic) {
        if (options != null)
            _worker = untyped __js__("new Worker({0}, {1})", url, options);
        else
            _worker = untyped __js__("new Worker({0})", url);
    }

    /**
     * Sends a message to the worker.
     * @param data Any serializable value.
     * @param transfer Optional array of Transferable objects (e.g. ArrayBuffer).
     */
    public inline function post(data:Dynamic, ?transfer:Array<Dynamic>):Void {
        if (transfer != null)
            untyped _worker.postMessage(data, transfer);
        else
            untyped _worker.postMessage(data);
    }

    /**
     * Registers a callback for messages received from the worker.
     * The callback receives the raw `MessageEvent`.
     */
    public inline function onMessage(callback:Dynamic -> Void):Void {
        untyped _worker.onmessage = callback;
    }

    /**
     * Registers a callback for errors thrown inside the worker.
     * The callback receives the raw `ErrorEvent`.
     */
    public inline function onError(callback:Dynamic -> Void):Void {
        untyped _worker.onerror = callback;
    }

    /**
     * Registers a callback for `messageerror` events
     * (fired when a message cannot be deserialized).
     */
    public inline function onMessageError(callback:Dynamic -> Void):Void {
        untyped _worker.onmessageerror = callback;
    }

    /** Immediately terminates the worker thread. */
    public inline function terminate():Void {
        untyped _worker.terminate();
    }

    /** Returns the raw underlying `Worker` JS object. */
    public inline function unwrap():Dynamic {
        return _worker;
    }
}
