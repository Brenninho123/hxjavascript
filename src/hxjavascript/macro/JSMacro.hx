package hxjavascript.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Compile-time macros for hxjavascript.
 *
 * `@:build(hxjavascript.macro.JSMacro.buildExtern())`
 * Automatically generates typed `get_*` / `set_*` property accessors
 * for fields annotated with `@jsProperty` on an `extern` class,
 * mapping them directly to `untyped __js__` reads/writes.
 *
 * Usage on a class:
 * ```haxe
 * @:build(hxjavascript.macro.JSMacro.buildExtern())
 * class MyLib {
 *     @jsProperty public static var version:String;
 * }
 * ```
 */
class JSMacro {
    /**
     * Build macro: for each static field marked `@jsProperty`,
     * replaces it with a read/write property backed by `untyped __js__`.
     */
    public static function buildExtern():Array<Field> {
        var fields = Context.getBuildFields();
        var result:Array<Field> = [];

        for (field in fields) {
            var hasJSProp = false;
            for (meta in field.meta) {
                if (meta.name == "jsProperty" || meta.name == ":jsProperty") {
                    hasJSProp = true;
                    break;
                }
            }

            if (!hasJSProp) {
                result.push(field);
                continue;
            }

            // Only handle static vars
            switch (field.kind) {
                case FVar(type, _):
                    var name = field.name;
                    var pos = field.pos;

                    // getter
                    result.push({
                        name: "get_" + name,
                        access: [AStatic, AInline, APrivate],
                        pos: pos,
                        kind: FFun({
                            args: [],
                            ret: type,
                            expr: macro return untyped __js__($v{name})
                        })
                    });

                    // setter
                    result.push({
                        name: "set_" + name,
                        access: [AStatic, AInline, APrivate],
                        pos: pos,
                        kind: FFun({
                            args: [{ name: "v", type: type }],
                            ret: type,
                            expr: macro { untyped __js__($v{name} + " = " + v); return v; }
                        })
                    });

                    // property
                    result.push({
                        name: name,
                        access: field.access,
                        pos: pos,
                        meta: [],
                        kind: FProp("get_" + name, "set_" + name, type, null)
                    });

                default:
                    result.push(field);
            }
        }

        return result;
    }
}
#end
