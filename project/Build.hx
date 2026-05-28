import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import haxe.Json;
import haxe.io.Path;

using StringTools;

class Build {

    static final RESET  = "\x1b[0m";
    static final BOLD   = "\x1b[1m";
    static final DIM    = "\x1b[2m";
    static final RED    = "\x1b[31m";
    static final GREEN  = "\x1b[32m";
    static final YELLOW = "\x1b[33m";
    static final CYAN   = "\x1b[36m";
    static final WHITE  = "\x1b[37m";

    static final VALID_TASKS  = ["compile", "test", "package", "clean", "watch", "lint", "all"];
    static final SRC_DIR      = "src";
    static final BIN_DIR      = "bin";
    static final DIST_DIR     = "dist";
    static final HAXELIB_JSON = "haxelib.json";
    static final TEST_ENTRY   = "Test.hx";
    static final TEST_OUT     = "bin/test.js";
    static final PACKAGE_OUT  = "dist/hxjavascript.zip";

    static var release  = false;
    static var task     = "all";
    static var watchMs  = 800;
    static var exitCode = 0;
    static var startMs  = 0.0;

    static function main() {
        startMs = haxe.Timer.stamp();
        parseArgs(Sys.args());
        ensureDirs([BIN_DIR, DIST_DIR]);

        switch (task) {
            case "compile": compile();
            case "test":    compile(); runTests();
            case "package": compile(); runTests(); pkg();
            case "clean":   clean();
            case "watch":   watchLoop();
            case "lint":    lint();
            case "all":     clean(); compile(); lint(); runTests(); pkg();
            default:
                die('Unknown task "$task". Valid: ${VALID_TASKS.join(", ")}');
        }

        printSummary();
        Sys.exit(exitCode);
    }

    static function parseArgs(args:Array<String>) {
        var i = 0;
        while (i < args.length) {
            switch (args[i]) {
                case "--task", "-t":
                    task = args[++i];
                case "--release", "-r":
                    release = true;
                case "--watch-interval":
                    watchMs = Std.parseInt(args[++i]) ?? 800;
                case "--help", "-h":
                    printHelp();
                    Sys.exit(0);
                default:
                    if (!args[i].startsWith("-"))
                        task = args[i];
                    else
                        warn('Unknown flag: ${args[i]}');
            }
            i++;
        }
    }

    static function compile() {
        step("COMPILE");

        var hxml = buildHxml();
        var tmpHxml = ".build_tmp.hxml";
        File.saveContent(tmpHxml, hxml);

        var result = exec("haxe", [tmpHxml]);
        FileSystem.deleteFile(tmpHxml);

        if (result.code != 0) {
            printLines(result.stderr, RED);
            fail("Compilation failed");
        } else {
            ok('Output → $TEST_OUT (${fileSize(TEST_OUT)})');
        }
    }

    static function buildHxml():String {
        var lines = [
            "-cp " + SRC_DIR,
            "-cp .",
            "-js " + TEST_OUT,
            "-main Test",
            "--no-output false"
        ];
        if (release) {
            lines.push("-dce full");
            lines.push("-D js-es=6");
        } else {
            lines.push("-debug");
            lines.push("-D js-es=5");
        }
        return lines.join("\n") + "\n";
    }

    static function runTests() {
        step("TEST");

        if (!FileSystem.exists(TEST_OUT)) {
            fail("$TEST_OUT not found — run compile first");
            return;
        }

        var nodeCheck = exec("node", ["--version"]);
        if (nodeCheck.code != 0) {
            warn("node not found — skipping runtime tests");
            return;
        }

        var result = exec("node", [TEST_OUT]);
        if (result.code != 0) {
            printLines(result.stderr, RED);
            fail("Test run failed (exit ${result.code})");
        } else {
            printLines(result.stdout, DIM);
            ok("All tests passed");
        }
    }

    static function lint() {
        step("LINT");

        var files = collectHaxeFiles(SRC_DIR);
        var issues = 0;

        for (path in files) {
            var src = File.getContent(path);
            var lines = src.split("\n");
            for (i in 0...lines.length) {
                var ln = lines[i];
                if (ln.contains("trace(")) {
                    warn('  ${path}:${i+1} — trace() call detected');
                    issues++;
                }
                if (ln.trimLeft().startsWith("//")) {
                    warn('  ${path}:${i+1} — inline comment detected');
                    issues++;
                }
                if (ln.contains("TODO") || ln.contains("FIXME") || ln.contains("HACK")) {
                    warn('  ${path}:${i+1} — marker annotation detected');
                    issues++;
                }
                if (ln.length > 120) {
                    warn('  ${path}:${i+1} — line exceeds 120 chars (${ln.length})');
                    issues++;
                }
            }
        }

        if (issues == 0)
            ok('${files.length} files checked — no issues');
        else
            warn('${issues} issue(s) found in ${files.length} files');
    }

    static function pkg() {
        step("PACKAGE");

        var meta = readMeta();
        var version:String = meta.version ?? "0.0.0";
        var zipName = 'hxjavascript-${version}.zip';
        var zipPath = Path.join([DIST_DIR, zipName]);
        var stableZip = PACKAGE_OUT;

        validateMeta(meta);

        var entries = collectZipEntries();
        writeZip(zipPath, entries);
        File.copy(zipPath, stableZip);

        ok('Packaged ${entries.length} files → $zipPath');
        ok('Stable symlink → $stableZip');
        print('  $DIM${entries.map(e -> e.path).join("\n  ")}$RESET');
    }

    static function clean() {
        step("CLEAN");

        var removed = 0;
        for (dir in [BIN_DIR, DIST_DIR]) {
            if (FileSystem.exists(dir)) {
                deleteDir(dir);
                removed++;
            }
        }
        for (tmp in [".build_tmp.hxml"]) {
            if (FileSystem.exists(tmp)) {
                FileSystem.deleteFile(tmp);
                removed++;
            }
        }
        ensureDirs([BIN_DIR, DIST_DIR]);
        ok('Removed $removed paths');
    }

    static function watchLoop() {
        step("WATCH");
        print('  Watching $SRC_DIR every ${watchMs}ms — Ctrl+C to stop\n');

        var snapshots = buildSnapshot();

        while (true) {
            haxe.Timer.delay(() -> {}, watchMs);
            Sys.sleep(watchMs / 1000);

            var current = buildSnapshot();
            var changed:Array<String> = [];

            for (path => mtime in current) {
                if (!snapshots.exists(path) || snapshots.get(path) != mtime)
                    changed.push(path);
            }

            if (changed.length > 0) {
                print('\n  $CYAN[${timestamp()}]$RESET Changes detected:');
                for (f in changed) print('    $DIM$f$RESET');
                snapshots = current;
                exitCode = 0;
                compile();
                runTests();
            }
        }
    }

    static function buildSnapshot():Map<String, Float> {
        var map = new Map<String, Float>();
        for (f in collectHaxeFiles(SRC_DIR))
            map.set(f, FileSystem.stat(f).mtime.getTime());
        return map;
    }

    static function collectZipEntries():Array<{ path:String, data:haxe.io.Bytes }> {
        var entries = [];
        var include = collectHaxeFiles(SRC_DIR);

        for (f in [HAXELIB_JSON, "README.md", "LICENSE", "build.hxml"]) {
            if (FileSystem.exists(f))
                include.push(f);
        }

        for (path in include) {
            entries.push({
                path: path,
                data: haxe.io.Bytes.ofString(File.getContent(path))
            });
        }
        return entries;
    }

    static function writeZip(dest:String, entries:Array<{ path:String, data:haxe.io.Bytes }>) {
        var zip = new haxe.zip.Writer(File.write(dest, true));
        var fileList:List<haxe.zip.Entry> = new List();

        for (e in entries) {
            var compressed = haxe.zip.Compress.run(e.data, 9);
            fileList.add({
                fileName:     e.path,
                fileSize:     e.data.length,
                fileTime:     Date.now(),
                compressed:   true,
                dataSize:     compressed.length,
                data:         compressed,
                crc32:        haxe.crypto.Crc32.make(e.data),
                extraFields:  new List()
            });
        }
        zip.write(fileList);
    }

    static function validateMeta(meta:Dynamic) {
        var required = ["name", "url", "license", "version", "contributors"];
        for (field in required) {
            if (Reflect.field(meta, field) == null)
                warn('haxelib.json missing required field: "$field"');
        }

        var version:String = meta.version ?? "";
        var parts = version.split(".");
        if (parts.length != 3 || parts.filter(p -> Std.parseInt(p) == null && p != "0").length > 0)
            warn('haxelib.json version "$version" does not follow semver (X.Y.Z)');
    }

    static function readMeta():Dynamic {
        if (!FileSystem.exists(HAXELIB_JSON))
            die('$HAXELIB_JSON not found');
        return Json.parse(File.getContent(HAXELIB_JSON));
    }

    static function collectHaxeFiles(dir:String):Array<String> {
        var result = [];
        if (!FileSystem.exists(dir)) return result;
        for (item in FileSystem.readDirectory(dir)) {
            var full = Path.join([dir, item]);
            if (FileSystem.isDirectory(full))
                result = result.concat(collectHaxeFiles(full));
            else if (item.endsWith(".hx"))
                result.push(full);
        }
        return result;
    }

    static function deleteDir(path:String) {
        for (item in FileSystem.readDirectory(path)) {
            var full = Path.join([path, item]);
            if (FileSystem.isDirectory(full)) deleteDir(full);
            else FileSystem.deleteFile(full);
        }
        FileSystem.deleteDirectory(path);
    }

    static function ensureDirs(dirs:Array<String>) {
        for (d in dirs)
            if (!FileSystem.exists(d))
                FileSystem.createDirectory(d);
    }

    static function exec(cmd:String, args:Array<String>):{ code:Int, stdout:String, stderr:String } {
        var p = new Process(cmd, args);
        var stdout = p.stdout.readAll().toString();
        var stderr = p.stderr.readAll().toString();
        var code   = p.exitCode();
        p.close();
        return { code: code, stdout: stdout, stderr: stderr };
    }

    static function fileSize(path:String):String {
        if (!FileSystem.exists(path)) return "0 B";
        var bytes = FileSystem.stat(path).size;
        if (bytes < 1024)       return '${bytes} B';
        if (bytes < 1048576)    return '${Math.round(bytes / 102.4) / 10} KB';
        return '${Math.round(bytes / 104857.6) / 10} MB';
    }

    static function timestamp():String {
        var d = Date.now();
        return '${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}';
    }

    static function pad(n:Int):String {
        return n < 10 ? "0" + n : Std.string(n);
    }

    static function printLines(s:String, color:String) {
        for (ln in s.split("\n"))
            if (ln.trim().length > 0)
                Sys.println('  $color$ln$RESET');
    }

    static function step(name:String) {
        Sys.println('$BOLD$CYAN\n[$name]$RESET');
    }

    static function ok(msg:String) {
        Sys.println('  $GREEN✔$RESET $msg');
    }

    static function warn(msg:String) {
        Sys.println('  $YELLOW⚠$RESET  $msg');
    }

    static function fail(msg:String) {
        Sys.println('  $RED✖$RESET $msg');
        exitCode = 1;
    }

    static function die(msg:String) {
        Sys.println('$RED$BOLD[FATAL]$RESET $msg');
        Sys.exit(1);
    }

    static function print(msg:String) {
        Sys.println(msg);
    }

    static function printHelp() {
        Sys.println('
${BOLD}hxjavascript Build System$RESET

${BOLD}Usage:$RESET
  haxe --run Build [task] [options]

${BOLD}Tasks:$RESET
  compile    Compile Haxe sources to JS
  test       Compile + run tests via Node.js
  lint       Static analysis (trace, comments, line length)
  package    Compile + test + create haxelib ZIP
  clean      Remove bin/ and dist/
  watch      Watch src/ and recompile on change
  all        clean → compile → lint → test → package  (default)

${BOLD}Options:$RESET
  --release, -r        Enable DCE + ES6 output
  --watch-interval N   Polling interval in ms (default: 800)
  --help, -h           Show this help
');
    }

    static function printSummary() {
        var elapsed = Math.round((haxe.Timer.stamp() - startMs) * 1000);
        var color   = exitCode == 0 ? GREEN : RED;
        var status  = exitCode == 0 ? "SUCCESS" : "FAILED";
        Sys.println('\n$BOLD$color[$status]$RESET ${DIM}${elapsed}ms$RESET\n');
    }
}
