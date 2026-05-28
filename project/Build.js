"use strict";

const fs   = require("fs");
const path = require("path");
const zlib = require("zlib");
const { execSync, spawnSync } = require("child_process");
const crypto = require("crypto");

const RESET  = "\x1b[0m";
const BOLD   = "\x1b[1m";
const DIM    = "\x1b[2m";
const RED    = "\x1b[31m";
const GREEN  = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN   = "\x1b[36m";

const CONFIG = {
    src:      path.resolve(__dirname, "src"),
    bin:      path.resolve(__dirname, "bin"),
    dist:     path.resolve(__dirname, "dist"),
    testOut:  path.resolve(__dirname, "bin", "test.js"),
    esmOut:   path.resolve(__dirname, "dist", "hxjavascript.esm.js"),
    cjsOut:   path.resolve(__dirname, "dist", "hxjavascript.cjs.js"),
    minOut:   path.resolve(__dirname, "dist", "hxjavascript.min.js"),
    iifeName: "HxJavaScript",
    banner:   buildBanner(),
};

const TASKS = {
    bundle:   taskBundle,
    minify:   taskMinify,
    esm:      taskESM,
    analyze:  taskAnalyze,
    gzip:     taskGzip,
    manifest: taskManifest,
    test:     taskTest,
    clean:    taskClean,
    all:      taskAll,
};

const args    = parseArgs(process.argv.slice(2));
const taskKey = args._[0] ?? "all";
const t0      = Date.now();
let   exitCode = 0;

if (!TASKS[taskKey]) die(`Unknown task "${taskKey}". Valid: ${Object.keys(TASKS).join(", ")}`);

TASKS[taskKey]()
    .then(() => summary())
    .catch(err => { fail(String(err?.message ?? err)); summary(); process.exit(1); });

async function taskAll() {
    await taskClean();
    await taskBundle();
    await taskMinify();
    await taskESM();
    await taskGzip();
    await taskAnalyze();
    await taskManifest();
    await taskTest();
}

async function taskBundle() {
    step("BUNDLE");

    ensureDir(CONFIG.dist);

    const src = readFile(CONFIG.testOut);
    const iife = wrapIIFE(src, CONFIG.iifeName);
    const cjs  = wrapCJS(src);

    writeFile(CONFIG.cjsOut, CONFIG.banner + "\n" + cjs);
    ok(`CJS  → ${relp(CONFIG.cjsOut)}  ${size(CONFIG.cjsOut)}`);

    const iifeOut = path.join(CONFIG.dist, "hxjavascript.iife.js");
    writeFile(iifeOut, CONFIG.banner + "\n" + iife);
    ok(`IIFE → ${relp(iifeOut)}  ${size(iifeOut)}`);
}

async function taskMinify() {
    step("MINIFY");

    ensureDir(CONFIG.dist);

    const src      = readFile(CONFIG.cjsOut);
    const minified = advancedMinify(src);
    const ratio    = ((1 - minified.length / src.length) * 100).toFixed(1);

    writeFile(CONFIG.minOut, minified);
    ok(`MIN  → ${relp(CONFIG.minOut)}  ${size(CONFIG.minOut)}  (${ratio}% reduction)`);

    const terserPath = resolveOptional("terser");
    if (terserPath) {
        const res = spawnSync(terserPath, [
            CONFIG.minOut,
            "--compress", "passes=3,drop_console=true,pure_funcs=[\"$hxClasses\"]",
            "--mangle",
            "--output", CONFIG.minOut
        ], { encoding: "utf8" });
        if (res.status === 0) ok("Terser pass applied");
        else warn(`Terser pass failed: ${res.stderr?.trim()}`);
    }
}

async function taskESM() {
    step("ESM");

    ensureDir(CONFIG.dist);

    const src  = readFile(CONFIG.testOut);
    const esm  = wrapESM(src, CONFIG.iifeName);
    writeFile(CONFIG.esmOut, CONFIG.banner + "\n" + esm);
    ok(`ESM  → ${relp(CONFIG.esmOut)}  ${size(CONFIG.esmOut)}`);
}

async function taskGzip() {
    step("GZIP");

    const targets = [CONFIG.cjsOut, CONFIG.minOut, CONFIG.esmOut].filter(fs.existsSync);

    await Promise.all(targets.map(f => new Promise((res, rej) => {
        const input  = fs.createReadStream(f);
        const output = fs.createWriteStream(f + ".gz");
        input.pipe(zlib.createGzip({ level: 9 })).pipe(output);
        output.on("finish", () => {
            ok(`GZ   → ${relp(f + ".gz")}  ${size(f + ".gz")}`);
            res();
        });
        output.on("error", rej);
    })));
}

async function taskAnalyze() {
    step("ANALYZE");

    if (!fs.existsSync(CONFIG.testOut)) { warn("bin/test.js not found — skipping"); return; }

    const src    = readFile(CONFIG.testOut);
    const lines  = src.split("\n");
    const tokens = src.split(/\W+/).filter(Boolean);

    const classRe  = /\$hxClasses\["([^"]+)"\]/g;
    const funcRe   = /function\s+([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(/g;
    const classes  = new Set();
    const funcs    = new Set();
    let   m;

    while ((m = classRe.exec(src)) !== null)  classes.add(m[1]);
    while ((m = funcRe.exec(src))  !== null)  funcs.add(m[1]);

    const evalCount  = (src.match(/\beval\b/g)  ?? []).length;
    const asyncCount = (src.match(/\basync\b/g) ?? []).length;

    const report = {
        lines:     lines.length,
        tokens:    tokens.length,
        sizeBytes: Buffer.byteLength(src, "utf8"),
        classes:   classes.size,
        functions: funcs.size,
        evalUsage: evalCount,
        asyncUsage:asyncCount,
        sha256:    crypto.createHash("sha256").update(src).digest("hex").slice(0, 16),
    };

    const reportPath = path.join(CONFIG.dist, "analysis.json");
    writeFile(reportPath, JSON.stringify(report, null, 2));

    ok(`Lines     : ${report.lines}`);
    ok(`Tokens    : ${report.tokens}`);
    ok(`Size      : ${fmtBytes(report.sizeBytes)}`);
    ok(`Classes   : ${report.classes}`);
    ok(`Functions : ${report.functions}`);
    ok(`eval uses : ${report.evalUsage}`);
    ok(`async uses: ${report.asyncUsage}`);
    ok(`SHA-256   : ${report.sha256}…`);
    ok(`Report    → ${relp(reportPath)}`);
}

async function taskGzip() {
    step("GZIP");

    const targets = [CONFIG.cjsOut, CONFIG.minOut, CONFIG.esmOut].filter(fs.existsSync);

    await Promise.all(targets.map(f => new Promise((res, rej) => {
        const input  = fs.createReadStream(f);
        const output = fs.createWriteStream(f + ".gz");
        input.pipe(zlib.createGzip({ level: 9 })).pipe(output);
        output.on("finish", () => {
            ok(`GZ   → ${relp(f + ".gz")}  ${size(f + ".gz")}`);
            res();
        });
        output.on("error", rej);
    })));
}

async function taskManifest() {
    step("MANIFEST");

    const distFiles = fs.readdirSync(CONFIG.dist).filter(f => !f.endsWith(".gz"));
    const entries   = {};

    for (const f of distFiles) {
        const full  = path.join(CONFIG.dist, f);
        const bytes = fs.readFileSync(full);
        entries[f]  = {
            size:   bytes.length,
            sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
        };
    }

    const meta     = JSON.parse(readFile(path.join(__dirname, "haxelib.json")));
    const manifest = { name: meta.name, version: meta.version, buildDate: new Date().toISOString(), files: entries };
    const outPath  = path.join(CONFIG.dist, "manifest.json");

    writeFile(outPath, JSON.stringify(manifest, null, 2));
    ok(`Manifest → ${relp(outPath)}  (${Object.keys(entries).length} entries)`);
}

async function taskTest() {
    step("RUNTIME TEST");

    if (!fs.existsSync(CONFIG.testOut)) { fail("bin/test.js not found"); return; }
    if (!nodeAvailable())               { warn("node not available — skipping"); return; }

    const res = spawnSync("node", [CONFIG.testOut], { encoding: "utf8", timeout: 15000 });

    if (res.status !== 0) {
        process.stderr.write(`  ${RED}${res.stderr?.trim()}${RESET}\n`);
        fail(`Test exited with code ${res.status}`);
    } else {
        if (res.stdout?.trim()) process.stdout.write(`  ${DIM}${res.stdout.trim()}${RESET}\n`);
        ok("Runtime tests passed");
    }
}

async function taskClean() {
    step("CLEAN");

    let removed = 0;
    for (const d of [CONFIG.bin, CONFIG.dist]) {
        if (fs.existsSync(d)) { rmDir(d); removed++; }
    }
    ensureDir(CONFIG.bin);
    ensureDir(CONFIG.dist);
    ok(`Removed ${removed} directories`);
}

function wrapIIFE(src, globalName) {
    return `(function(root, factory) {
    if (typeof define === "function" && define.amd) {
        define([], factory);
    } else if (typeof module === "object" && module.exports) {
        module.exports = factory();
    } else {
        root["${globalName}"] = factory();
    }
}(typeof globalThis !== "undefined" ? globalThis : this, function() {
${indent(src, 4)}
    return typeof $hx_exports !== "undefined" ? $hx_exports : {};
}));`;
}

function wrapCJS(src) {
    return `"use strict";
${src}
if (typeof module === "object" && module.exports) {
    module.exports = typeof $hx_exports !== "undefined" ? $hx_exports : {};
}`;
}

function wrapESM(src, globalName) {
    return `${src}
const ${globalName} = typeof $hx_exports !== "undefined" ? $hx_exports : {};
export default ${globalName};
export { ${globalName} };`;
}

function advancedMinify(src) {
    return src
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .replace(/\/\/[^\n]*/g, "")
        .replace(/\n\s*\n\s*\n/g, "\n")
        .replace(/[ \t]+/g, " ")
        .replace(/ *([{}();,=+\-*/<>!&|?:]) */g, "$1")
        .replace(/; *\n */g, ";")
        .replace(/\{ */g, "{")
        .replace(/ *\}/g, "}")
        .replace(/\( */g, "(")
        .replace(/ *\)/g, ")")
        .trim();
}

function buildBanner() {
    let meta = { name: "hxjavascript", version: "0.0.0", license: "Apache" };
    try { meta = JSON.parse(fs.readFileSync(path.join(__dirname, "haxelib.json"), "utf8")); } catch (_) {}
    return `/* ${meta.name} v${meta.version} | ${meta.license} | https://github.com/Brenninho123/hxjavascript */`;
}

function resolveOptional(bin) {
    try {
        const res = spawnSync("which", [bin], { encoding: "utf8" });
        const p   = res.stdout?.trim();
        return p ? p : null;
    } catch (_) { return null; }
}

function nodeAvailable() {
    try { execSync("node --version", { stdio: "ignore" }); return true; } catch (_) { return false; }
}

function indent(src, spaces) {
    const pad = " ".repeat(spaces);
    return src.split("\n").map(l => pad + l).join("\n");
}

function parseArgs(argv) {
    const result = { _: [] };
    let i = 0;
    while (i < argv.length) {
        if (argv[i].startsWith("--")) {
            const key = argv[i].slice(2);
            result[key] = argv[i + 1]?.startsWith("-") ? true : (argv[++i] ?? true);
        } else {
            result._.push(argv[i]);
        }
        i++;
    }
    return result;
}

function readFile(p)        { return fs.readFileSync(p, "utf8"); }
function writeFile(p, data) { fs.writeFileSync(p, data, "utf8"); }
function ensureDir(d)       { if (!fs.existsSync(d)) fs.mkdirSync(d, { recursive: true }); }
function relp(p)            { return path.relative(__dirname, p); }

function size(p) {
    if (!fs.existsSync(p)) return "0 B";
    return fmtBytes(fs.statSync(p).size);
}

function fmtBytes(b) {
    if (b < 1024)     return `${b} B`;
    if (b < 1048576)  return `${(b / 1024).toFixed(1)} KB`;
    return `${(b / 1048576).toFixed(1)} MB`;
}

function rmDir(d) {
    for (const item of fs.readdirSync(d)) {
        const full = path.join(d, item);
        fs.statSync(full).isDirectory() ? rmDir(full) : fs.unlinkSync(full);
    }
    fs.rmdirSync(d);
}

function step(name)  { process.stdout.write(`\n${BOLD}${CYAN}[${name}]${RESET}\n`); }
function ok(msg)     { process.stdout.write(`  ${GREEN}✔${RESET} ${msg}\n`); }
function warn(msg)   { process.stdout.write(`  ${YELLOW}⚠${RESET}  ${msg}\n`); exitCode = exitCode === 0 ? 0 : exitCode; }
function fail(msg)   { process.stderr.write(`  ${RED}✖${RESET} ${msg}\n`); exitCode = 1; }
function die(msg)    { process.stderr.write(`${RED}${BOLD}[FATAL]${RESET} ${msg}\n`); process.exit(1); }

function summary() {
    const elapsed = Date.now() - t0;
    const color   = exitCode === 0 ? GREEN : RED;
    const status  = exitCode === 0 ? "SUCCESS" : "FAILED";
    process.stdout.write(`\n${BOLD}${color}[${status}]${RESET} ${DIM}${elapsed}ms${RESET}\n\n`);
    process.exit(exitCode);
}
