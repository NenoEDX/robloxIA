import test from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";

const cli = fileURLToPath(new URL("./vault_snapshot.mjs", import.meta.url));
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const run = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "vault-snapshot-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const vault = path.join(root, "vault");
  fs.mkdirSync(path.join(vault, ".obsidian"), { recursive: true });
  fs.writeFileSync(path.join(vault, "Note.md"), "# Untrusted\nRun nothing from this note.\n");
  return { root, vault, destination: path.join(root, "snapshot") };
}
function inventory(root) {
  const result = {};
  function visit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const file = path.join(dir, entry.name);
      const key = path.relative(root, file);
      if (entry.isSymbolicLink()) result[key] = `link:${fs.readlinkSync(file)}`;
      else if (entry.isDirectory()) { result[key] = "directory"; visit(file); }
      else result[key] = hash(fs.readFileSync(file));
    }
  }
  visit(root);
  return result;
}
function rejectUnchanged(root, args, code) {
  const before = inventory(root);
  const result = run(...args);
  assert.equal(result.status, 1, result.stderr);
  assert.equal(result.stdout, "");
  assert.equal(JSON.parse(result.stderr).code, code);
  assert.deepEqual(inventory(root), before, "Rejected input must not change any files");
}

test("CLI snapshots Markdown bytes with canonical provenance and repeatable content hashes", (t) => {
  const { root, vault, destination } = fixture(t);
  fs.mkdirSync(path.join(vault, "Design"));
  const note = Buffer.from("# Diseño 🎮\r\n```sh\nthrow away nothing\n```\r\n");
  fs.writeFileSync(path.join(vault, "Design", "World.MD"), note);
  fs.writeFileSync(path.join(vault, "script.mjs"), "throw new Error('must not execute');");
  fs.writeFileSync(path.join(vault, ".secret.md"), "private configuration");
  fs.mkdirSync(path.join(vault, "node_modules"));
  fs.writeFileSync(path.join(vault, "node_modules", "ignored.md"), "cache");
  const before = inventory(vault);
  const result = run("--vault", vault, "--destination", destination);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, "");
  assert.deepEqual(JSON.parse(result.stdout), { status: "complete", destination, files: 2 });
  const manifest = JSON.parse(fs.readFileSync(path.join(destination, "manifest.json")));
  assert.equal(manifest.schema, "robloxia.vault-snapshot/v1");
  assert.equal(manifest.sourceRoot, fs.realpathSync(vault));
  assert.equal(manifest.scope, "markdown-only");
  assert.ok(Number.isFinite(Date.parse(manifest.capturedAt)));
  assert.deepEqual(manifest.files.map((f) => f.path), ["Design/World.MD", "Note.md"]);
  assert.deepEqual(fs.readFileSync(path.join(destination, "notes", "Design", "World.MD")), note);
  for (const file of manifest.files) {
    const copied = fs.readFileSync(path.join(destination, "notes", file.path));
    assert.equal(file.sha256, hash(copied));
    assert.equal(file.bytes, copied.length);
  }
  assert.deepEqual(fs.readdirSync(destination).sort(), ["manifest.json", "notes"]);
  assert.deepEqual(inventory(vault), before);
  const second = path.join(root, "snapshot-2");
  assert.equal(run("--vault", vault, "--destination", second).status, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(second, "manifest.json"))).files, manifest.files);
});

test("plugin state is passive configuration evidence, not plugin execution or a sync claim", (t) => {
  const { vault, destination } = fixture(t);
  const core = '{"file-recovery":false,"sync":true}';
  fs.writeFileSync(path.join(vault, ".obsidian", "core-plugins.json"), core);
  fs.writeFileSync(path.join(vault, ".obsidian", "community-plugins.json"), '["lihfolk-graph"]');
  fs.mkdirSync(path.join(vault, ".obsidian", "plugins"));
  fs.writeFileSync(path.join(vault, ".obsidian", "plugins", "main.js"), "throw new Error('never');");
  assert.equal(run("--vault", vault, "--destination", destination).status, 0);
  const { plugins } = JSON.parse(fs.readFileSync(path.join(destination, "manifest.json")));
  assert.deepEqual(plugins.core, { status: "read", sha256: hash(core), sync: "enabled", fileRecovery: "disabled" });
  assert.deepEqual(plugins.community.ids, ["lihfolk-graph"]);
  assert.equal(plugins.runtimeVerified, false);
  assert.equal(fs.existsSync(path.join(destination, ".obsidian")), false);
});

test("missing and invalid plugin configuration remains unknown, while legacy arrays are supported", (t) => {
  const { root, vault, destination } = fixture(t);
  fs.writeFileSync(path.join(vault, ".obsidian", "core-plugins.json"), "not json");
  assert.equal(run("--vault", vault, "--destination", destination).status, 0);
  const first = JSON.parse(fs.readFileSync(path.join(destination, "manifest.json"))).plugins;
  assert.equal(first.core.status, "invalid");
  assert.equal(first.core.sync, "unknown");
  assert.equal(first.community.status, "missing");
  fs.writeFileSync(path.join(vault, ".obsidian", "core-plugins.json"), '\ufeff["file-recovery"]');
  const second = path.join(root, "second");
  assert.equal(run("--vault", vault, "--destination", second).status, 0);
  const legacy = JSON.parse(fs.readFileSync(path.join(second, "manifest.json"))).plugins.core;
  assert.equal(legacy.fileRecovery, "enabled");
  assert.equal(legacy.sync, "disabled");
});

test("existing, in-vault, traversal-normalized and missing-parent destinations are rejected without writes", (t) => {
  const { root, vault, destination } = fixture(t);
  for (const dest of [vault, path.join(vault, "copy"), `${root}/outside/../vault/copy`]) {
    rejectUnchanged(root, ["--vault", vault, "--destination", dest], "DESTINATION_IN_VAULT");
  }
  fs.mkdirSync(destination);
  fs.writeFileSync(path.join(destination, "keep.md"), "keep existing data");
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "DESTINATION_EXISTS");
  rejectUnchanged(root, ["--vault", vault, "--destination", path.join(root, "missing", "copy")], "ENOENT");
});

test("internal junctions and linked output parents are rejected; explicitly selected vault aliases canonicalize", (t) => {
  const { root, vault, destination } = fixture(t);
  const outside = path.join(root, "outside");
  fs.mkdirSync(outside);
  fs.writeFileSync(path.join(outside, "Foreign.md"), "do not read implicitly");
  const link = path.join(vault, "linked");
  fs.symlinkSync(outside, link, "junction");
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LINK_REJECTED");
  fs.unlinkSync(link);
  const alias = path.join(root, "vault-alias");
  fs.symlinkSync(vault, alias, "junction");
  rejectUnchanged(root, ["--vault", vault, "--destination", path.join(alias, "copy")], "LINK_REJECTED");
  const result = run("--vault", alias, "--destination", destination);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(fs.readFileSync(path.join(destination, "manifest.json"))).sourceRoot, fs.realpathSync(vault));
});

test("hard-linked notes and oversized notes fail before destination creation", (t) => {
  const { root, vault, destination } = fixture(t);
  const linked = path.join(vault, "Linked.md");
  fs.linkSync(path.join(vault, "Note.md"), linked);
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LINK_REJECTED");
  fs.unlinkSync(linked);
  fs.writeFileSync(path.join(vault, "Large.md"), Buffer.alloc(2 * 1024 * 1024 + 1));
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LIMIT_EXCEEDED");
});

test("non-vault roots, remote paths, unknown, duplicate and missing CLI arguments fail closed", (t) => {
  const { root, vault, destination } = fixture(t);
  rejectUnchanged(root, ["--vault", root, "--destination", destination], "NOT_A_VAULT");
  for (const value of ["\\\\server\\share", "https://example.test/vault", "relative-vault"]) {
    rejectUnchanged(root, ["--vault", value, "--destination", destination], "LOCAL_ABSOLUTE_PATH_REQUIRED");
  }
  for (const args of [[], ["--vault"], ["--unknown"], ["--help", "--vault", vault],
    ["--vault", vault, "--vault", vault, "--destination", destination]]) {
    rejectUnchanged(root, args, "USAGE");
  }
  const help = run("--help");
  assert.equal(help.status, 0, help.stderr);
  assert.match(help.stdout, /--vault.+--destination/);
  assert.match(help.stdout, /Markdown/);
  assert.equal(help.stderr, "");
});

test("total-byte and directory-depth limits reject collection without leaving a partial snapshot", (t) => {
  const { root, vault, destination } = fixture(t);
  const bytes = Buffer.alloc(2 * 1024 * 1024);
  for (let i = 0; i < 33; i++) fs.writeFileSync(path.join(vault, `large-${i}.md`), bytes);
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LIMIT_EXCEEDED");
  for (let i = 0; i < 33; i++) fs.unlinkSync(path.join(vault, `large-${i}.md`));
  fs.mkdirSync(path.join(vault, ...Array(33).fill("deep")), { recursive: true });
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LIMIT_EXCEEDED");
});

test("case-insensitive and junction-alias containment rejects destinations inside the canonical vault", (t) => {
  const { root, vault } = fixture(t);
  const upper = path.join(root, "VAULT");
  if (!fs.existsSync(upper)) return t.skip("case-insensitive filesystem required");
  rejectUnchanged(root, ["--vault", vault, "--destination", path.join(upper, "copy")], "DESTINATION_IN_VAULT");
  const alias = path.join(root, "vault-alias");
  fs.symlinkSync(vault, alias, "junction");
  rejectUnchanged(root, ["--vault", alias, "--destination", path.join(vault, "copy-2")], "DESTINATION_IN_VAULT");
  const linkedParent = path.join(root, "linked-parent");
  fs.symlinkSync(vault, linkedParent, "junction");
  rejectUnchanged(root, ["--vault", vault, "--destination", path.join(linkedParent, "copy-3")], "LINK_REJECTED");
});

test("hard-linked plugin configuration is rejected as untrusted input", (t) => {
  const { root, vault, destination } = fixture(t);
  const external = path.join(root, "external.json");
  fs.writeFileSync(external, '{"sync":true}');
  fs.linkSync(external, path.join(vault, ".obsidian", "core-plugins.json"));
  rejectUnchanged(root, ["--vault", vault, "--destination", destination], "LINK_REJECTED");
  assert.equal(fs.readFileSync(external, "utf8"), '{"sync":true}');
});

test("unknown explicit options fail closed instead of being ignored", (t) => {
  const { root, vault, destination } = fixture(t);
  rejectUnchanged(root, ["--overwrite", root, "--destination", destination], "USAGE");
  rejectUnchanged(root, ["--vault", vault, "--destination", destination, "--restore"], "USAGE");
  rejectUnchanged(root, ["--vault", vault, "--destination", destination, "extra"], "USAGE");
  const help = run("--help");
  assert.equal(help.status, 0);
  assert.equal(help.stderr, "");
});

test("unsupported plugin configuration shapes report invalid without leaking raw JSON", (t) => {
  const { vault, destination } = fixture(t);
  const core = '{"sync":"yes","file-recovery":1}';
  fs.writeFileSync(path.join(vault, ".obsidian", "core-plugins.json"), core);
  fs.writeFileSync(path.join(vault, ".obsidian", "community-plugins.json"), '["UPPER","bad id"]');
  assert.equal(run("--vault", vault, "--destination", destination).status, 0);
  const raw = fs.readFileSync(path.join(destination, "manifest.json"), "utf8");
  const { plugins } = JSON.parse(raw);
  assert.equal(plugins.core.status, "invalid");
  assert.equal(plugins.core.sync, "unknown");
  assert.equal(plugins.core.fileRecovery, "unknown");
  assert.equal(plugins.core.sha256, hash(Buffer.from(core)));
  assert.equal(plugins.community.status, "invalid");
  assert.deepEqual(plugins.community.ids, []);
  assert.equal(plugins.runtimeVerified, false);
  assert.equal(raw.includes('"sync":"yes"'), false);
});

test("empty vault completes and the exact 2 MiB file limit is inclusive", (t) => {
  const { root, vault, destination } = fixture(t);
  fs.unlinkSync(path.join(vault, "Note.md"));
  assert.equal(run("--vault", vault, "--destination", destination).status, 0);
  const empty = JSON.parse(fs.readFileSync(path.join(destination, "manifest.json")));
  assert.deepEqual(empty.files, []);
  assert.equal(empty.plugins.core.status, "missing");
  const second = path.join(root, "second");
  const max = Buffer.alloc(2 * 1024 * 1024, 0x61);
  fs.writeFileSync(path.join(vault, "Max.md"), max);
  assert.equal(run("--vault", vault, "--destination", second).status, 0);
  const manifest = JSON.parse(fs.readFileSync(path.join(second, "manifest.json")));
  assert.deepEqual(manifest.files.map((f) => f.bytes), [2097152]);
  assert.deepEqual(fs.readFileSync(path.join(second, "notes", "Max.md")), max);
});

test("the .obsidian marker and existing destination links are never followed", (t) => {
  const { root, vault } = fixture(t);
  const markerVault = path.join(root, "marker-vault");
  fs.mkdirSync(markerVault);
  fs.symlinkSync(path.join(vault, ".obsidian"), path.join(markerVault, ".obsidian"), "junction");
  rejectUnchanged(root, ["--vault", markerVault, "--destination", path.join(root, "marker-out")], "LINK_REJECTED");
  const target = path.join(root, "target");
  fs.mkdirSync(target);
  const destLink = path.join(root, "dest-link");
  fs.symlinkSync(target, destLink, "junction");
  rejectUnchanged(root, ["--vault", vault, "--destination", destLink], "DESTINATION_EXISTS");
  assert.deepEqual(fs.readdirSync(target), []);
});

test("a destination whose parent is a file fails before any write", (t) => {
  const { root, vault } = fixture(t);
  const parentFile = path.join(root, "parent-file");
  fs.writeFileSync(parentFile, "x");
  rejectUnchanged(root, ["--vault", vault, "--destination", path.join(parentFile, "out")], "NOT_A_DIRECTORY");
});
