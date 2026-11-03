// Standalone local CLI: bounded synchronous I/O, never imported by the HTTP bridge.
import * as fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";

const LIMITS = { fileBytes: 2 * 1024 * 1024, totalBytes: 64 * 1024 * 1024, files: 10000, entries: 50000, depth: 32 };
const HELP = `Usage: node bridge/vault_snapshot.mjs --vault <absolute-path> --destination <new-absolute-path>
Create a local Markdown-only snapshot; never execute notes, plugins, or sync commands.
The vault must contain .obsidian. Its explicitly selected root may be an alias.
The destination parent must exist, contain no linked ancestors, and be outside the vault.
Existing destinations, internal links and network/URL paths are rejected. No overwrite or restore.
Limits: 2 MiB/file, 64 MiB total, 10,000 notes, 50,000 entries, depth 32.
Stop other filesystem writers first; this CLI is not an OS sandbox or atomic vault backup.
An output without manifest.json is incomplete. See docs/VAULT_SNAPSHOTS.md.
`;
const fail = (code) => { throw Object.assign(new Error(code), { code }); };
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
function localPath(value) {
  if (typeof value !== "string" || !path.isAbsolute(value) || /^[\\/]{2}/.test(value) || value.includes("\0")) {
    fail("LOCAL_ABSOLUTE_PATH_REQUIRED");
  }
  return path.resolve(value);
}
function within(root, file) {
  const relative = path.relative(root, file);
  return relative === "" || (!path.isAbsolute(relative) && relative !== ".." && !relative.startsWith(`..${path.sep}`));
}
function noLinks(file) {
  const stat = fs.lstatSync(file);
  if (stat.isSymbolicLink() || (stat.isFile() && stat.nlink !== 1)) fail("LINK_REJECTED");
  return stat;
}
function checkParents(dir) {
  for (let current = dir; ; current = path.dirname(current)) {
    if (!noLinks(current).isDirectory()) fail("NOT_A_DIRECTORY");
    if (path.dirname(current) === current) break;
  }
}
function absent(file) {
  try { fs.lstatSync(file); } catch (error) {
    if (error.code === "ENOENT") return;
    throw error;
  }
  fail("DESTINATION_EXISTS");
}
function safeName(name) {
  if (/[\\/:\x00-\x1f]/.test(name) || name === "." || name === "..") fail("UNSAFE_NAME");
}
function inside(root, file) {
  if (!within(root, file)) fail("PATH_ESCAPE");
  const relative = path.relative(root, file);
  let current = root;
  for (const part of relative.split(path.sep).filter(Boolean)) {
    safeName(part);
    current = path.join(current, part);
    noLinks(current);
  }
  if (!within(root, localPath(fs.realpathSync(file)))) fail("PATH_ESCAPE");
  return noLinks(file);
}
function sameFile(a, b) {
  return a.dev === b.dev && a.ino === b.ino && a.size === b.size && a.mtimeMs === b.mtimeMs && b.nlink === 1;
}
function readBounded(root, file) {
  const before = inside(root, file);
  if (!before.isFile()) fail("NOT_A_FILE");
  if (before.size > LIMITS.fileBytes) fail("LIMIT_EXCEEDED");
  const fd = fs.openSync(file, "r");
  try {
    if (!sameFile(before, fs.fstatSync(fd))) fail("SOURCE_CHANGED");
    const bytes = Buffer.alloc(before.size + 1);
    let length = 0;
    while (length < bytes.length) {
      const count = fs.readSync(fd, bytes, length, bytes.length - length, length);
      if (!count) break;
      length += count;
    }
    if (length !== before.size || !sameFile(before, fs.fstatSync(fd)) || !sameFile(before, inside(root, file))) {
      fail("SOURCE_CHANGED");
    }
    return bytes.subarray(0, length);
  } finally { fs.closeSync(fd); }
}
function pluginConfig(root, name) {
  const file = path.join(root, ".obsidian", name);
  try { fs.lstatSync(file); } catch (error) {
    if (error.code === "ENOENT") return { status: "missing" };
    throw error;
  }
  const bytes = readBounded(root, file);
  const sha256 = hash(bytes);
  try { return { status: "read", sha256, value: JSON.parse(bytes.toString("utf8").replace(/^\uFEFF/, "")) }; }
  catch { return { status: "invalid", sha256 }; }
}
function plugins(root) {
  const core = pluginConfig(root, "core-plugins.json");
  const community = pluginConfig(root, "community-plugins.json");
  const isIds = (value) => Array.isArray(value) && value.every((id) => typeof id === "string" && /^[a-z0-9-]{1,128}$/.test(id));
  const isCoreObject = core.value !== null && typeof core.value === "object" && !Array.isArray(core.value)
    && Object.values(core.value).every((v) => typeof v === "boolean");
  if (core.status === "read" && !isIds(core.value) && !isCoreObject) core.status = "invalid";
  if (community.status === "read" && !isIds(community.value)) community.status = "invalid";
  const state = (id) => {
    if (core.status !== "read") return "unknown";
    const enabled = Array.isArray(core.value) ? core.value.includes(id) : core.value[id];
    return enabled === true ? "enabled" : enabled === false ? "disabled" : "unknown";
  };
  const result = {
    core: { status: core.status, ...(core.sha256 && { sha256: core.sha256 }), sync: state("sync"), fileRecovery: state("file-recovery") },
    community: { status: community.status, ...(community.sha256 && { sha256: community.sha256 }), ids: community.status === "read" ? community.value : [] },
    runtimeVerified: false,
  };
  return result;
}
function collect(root) {
  const notes = [];
  let total = 0;
  let entries = 0;
  function walk(dir, depth) {
    if (depth > LIMITS.depth) fail("LIMIT_EXCEEDED");
    inside(root, dir);
    const handle = fs.opendirSync(dir);
    try {
      for (let entry = handle.readSync(); entry; entry = handle.readSync()) {
        if (++entries > LIMITS.entries) fail("LIMIT_EXCEEDED");
        safeName(entry.name);
        const file = path.join(dir, entry.name);
        const stat = noLinks(file);
        if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
        if (stat.isDirectory()) walk(file, depth + 1);
        else if (/\.md$/i.test(entry.name)) {
          if (notes.length >= LIMITS.files) fail("LIMIT_EXCEEDED");
          const bytes = readBounded(root, file);
          total += bytes.length;
          if (total > LIMITS.totalBytes) fail("LIMIT_EXCEEDED");
          notes.push({ path: path.relative(root, file).split(path.sep).join("/"), bytes });
        }
      }
    } finally { handle.closeSync(); }
  }
  walk(root, 0);
  notes.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  return notes;
}
function parse(args) {
  if (args.length !== 4) fail("USAGE");
  const options = {};
  for (let i = 0; i < args.length; i += 2) {
    if (!["--vault", "--destination"].includes(args[i]) || options[args[i]]) fail("USAGE");
    options[args[i]] = args[i + 1];
  }
  if (!options["--vault"] || !options["--destination"]) fail("USAGE");
  return { vault: localPath(options["--vault"]), destination: localPath(options["--destination"]) };
}

let created = false;
try {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === "--help") process.stdout.write(HELP);
  else {
    const { vault, destination } = parse(args);
    const sourceRoot = localPath(fs.realpathSync(vault));
    if (!noLinks(sourceRoot).isDirectory()) fail("NOT_A_VAULT");
    const marker = path.join(sourceRoot, ".obsidian");
    try {
      if (!noLinks(marker).isDirectory()) fail("NOT_A_VAULT");
    } catch (error) { if (error.code === "ENOENT") fail("NOT_A_VAULT"); throw error; }
    if (within(sourceRoot, destination)) fail("DESTINATION_IN_VAULT");
    const parent = path.dirname(destination);
    checkParents(parent);
    if (within(sourceRoot, fs.realpathSync(parent))) fail("DESTINATION_IN_VAULT");
    safeName(path.basename(destination));
    absent(destination);
    const pluginState = plugins(sourceRoot);
    const notes = collect(sourceRoot);
    const manifest = {
      schema: "robloxia.vault-snapshot/v1", sourceRoot, capturedAt: new Date().toISOString(),
      scope: "markdown-only", plugins: pluginState,
      files: notes.map((note) => ({ path: note.path, bytes: note.bytes.length, sha256: hash(note.bytes) })),
    };
    checkParents(parent);
    fs.mkdirSync(destination, { mode: 0o700 }); // Exclusive: a racing existing destination is never reused.
    created = true;
    fs.mkdirSync(path.join(destination, "notes"), { mode: 0o700 });
    for (const note of notes) {
      const file = path.join(destination, "notes", note.path);
      fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
      checkParents(path.dirname(file));
      fs.writeFileSync(file, note.bytes, { flag: "wx", mode: 0o600 });
    }
    checkParents(destination);
    fs.writeFileSync(path.join(destination, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n", { flag: "wx", mode: 0o600 });
    process.stdout.write(JSON.stringify({ status: "complete", destination, files: notes.length }) + "\n");
  }
} catch (error) {
  process.stderr.write(JSON.stringify({ status: created ? "incomplete" : "rejected", code: error.code ?? "SNAPSHOT_FAILED" }) + "\n");
  process.exitCode = 1;
}
