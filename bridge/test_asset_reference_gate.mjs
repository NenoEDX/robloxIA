import test from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";

const cli = fileURLToPath(new URL("./asset_reference_gate.mjs", import.meta.url));
const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
const run = (...args) => spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });

// Deterministic proof that the CLI never performs an unbounded whole-file read: stat is
// reported tiny, the real file is over the limit, and readFileSync is booby-trapped.
const FS_MOCK = `
const real = globalThis.__REAL_FS;
const reported = Number(process.env.ASSET_GATE_FAKE_SIZE);
export const lstatSync = (file, options) => new Proxy(real.lstatSync(file, options), {
  get(target, property) {
    if (property === "size") return reported;
    const value = Reflect.get(target, property, target);
    return typeof value === "function" ? value.bind(target) : value;
  },
});
export const openSync = (...args) => real.openSync(...args);
export const readSync = (...args) => real.readSync(...args);
export const closeSync = (...args) => real.closeSync(...args);
export const readFileSync = () => { throw new Error("UNBOUNDED_READ"); };
`;
const PRELOAD = `
import { createRequire, registerHooks } from "node:module";
if (typeof registerHooks !== "function") throw new Error("NODE_REGISTER_HOOKS_UNAVAILABLE");
globalThis.__REAL_FS = createRequire(import.meta.url)("node:fs");
const mock = new URL("./fs-mock.mjs", import.meta.url).href;
registerHooks({
  resolve(specifier, context, nextResolve) {
    const isRequire = Array.isArray(context.conditions) && context.conditions.includes("require");
    if (!isRequire && (specifier === "node:fs" || specifier === "fs")) return { url: mock, shortCircuit: true };
    return nextResolve(specifier, context);
  },
});
`;

function request() {
  return {
    schema: "robloxia.asset-request/v1",
    assetId: "slime-crate-proto-01",
    assetKind: "mesh",
    references: [
      {
        id: "ref-crate-concept-01",
        source: "vault://slime/concepts/crate-front.png",
        license: "project-owned",
        sha256: "a".repeat(64),
      },
    ],
    approval: {
      approvedBy: "fictional-reviewer-placeholder",
      approvedAt: "2026-10-01T12:00:00Z",
      referenceIds: ["ref-crate-concept-01"],
    },
    delivery: {
      status: "exported",
      evidence: "exports/slime/crate.glb",
      exportedAt: "2026-10-02T09:30:00Z",
    },
    budget: {
      metric: "triangles",
      limit: 20000,
      measured: 12345,
      evidence: "blender validate_mesh_budget report",
    },
  };
}

function workspace(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "asset-gate-test-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

function writeRecord(root, value, name = "request.json") {
  const file = path.join(root, name);
  fs.writeFileSync(file, typeof value === "string" ? value : JSON.stringify(value, null, 2));
  return file;
}

function assertRejectedFile(file, expected) {
  const before = fs.readFileSync(file);
  const result = run("--request", file);
  assert.equal(result.status, 1, result.stderr);
  assert.equal(result.stdout, "");
  const report = JSON.parse(result.stderr);
  assert.equal(report.status, "rejected");
  for (const [code, at] of expected) {
    assert.ok(
      report.errors.some((error) => error.code === code && (!at || error.path === at)),
      `${code} at ${at ?? "*"} missing from ${result.stderr}`,
    );
  }
  assert.deepEqual(fs.readFileSync(file), before, "a rejected record must stay byte-identical");
  return report;
}

function expectRejected(t, mutate, expected, name = "request.json") {
  const value = request();
  mutate(value);
  return assertRejectedFile(writeRecord(workspace(t), value, name), expected);
}

function expectRejectedRaw(t, text, expected, name = "request.json") {
  return assertRejectedFile(writeRecord(workspace(t), text, name), expected);
}

test("a complete record passes metadata checks yet authorizes and completes nothing", (t) => {
  const file = writeRecord(workspace(t), request());
  const before = fs.readFileSync(file);
  const result = run("--request", file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, "");
  const report = JSON.parse(result.stdout);
  assert.deepEqual(Object.keys(report).sort(), [
    "authorization", "completion", "input", "limitations", "manualInspection",
    "notGranted", "recorded", "schema", "status",
  ]);
  assert.equal(report.schema, "robloxia.asset-reference-gate/report-v1");
  assert.equal(report.status, "metadata_checks_passed");
  assert.equal(report.authorization, false);
  assert.equal(report.completion, "unverified");
  assert.equal(report.manualInspection, "required");
  assert.deepEqual(report.notGranted, [
    "human_approval", "asset_generation", "asset_import", "asset_upload", "publication", "quality_certification",
  ]);
  assert.deepEqual(report.limitations, [
    "Recorded identity, hashes and licenses are unverified claims; reference and evidence paths are never read.",
    "Passing metadata checks does not authorize generation, import, upload or publication.",
    "Explicit live human consent and real manual or Studio QA remain required.",
  ]);
  assert.deepEqual(report.input, { path: path.resolve(file), bytes: before.length, sha256: sha(before) });
  assert.deepEqual(report.recorded, {
    assetId: "slime-crate-proto-01",
    assetKind: "mesh",
    references: ["ref-crate-concept-01"],
    approvedBy: "fictional-reviewer-placeholder",
    approvedAt: "2026-10-01T12:00:00Z",
    referencesApproved: 1,
    deliveryStatus: "exported",
    budget: { metric: "triangles", limit: 20000, measured: 12345, headroom: 7655 },
  });
  assert.deepEqual(fs.readFileSync(file), before, "the gate is read-only");
});

test("impossible calendar timestamps are rejected instead of normalized", (t) => {
  expectRejected(t, (r) => { r.approval.approvedAt = "2026-02-30T12:00:00Z"; }, [["INVALID_TIMESTAMP", "approval.approvedAt"]]);
  expectRejected(t, (r) => { r.approval.approvedAt = "2026-02-29T12:00:00Z"; }, [["INVALID_TIMESTAMP", "approval.approvedAt"]]);
  expectRejected(t, (r) => { r.delivery.exportedAt = "2026-04-31T09:30:00Z"; }, [["INVALID_TIMESTAMP", "delivery.exportedAt"]]);
  const leap = request();
  leap.approval.approvedAt = "2024-02-29T12:00:00Z";
  leap.delivery.exportedAt = "2024-03-01T09:30:00Z";
  const file = writeRecord(workspace(t), leap);
  const result = run("--request", file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).recorded.approvedAt, "2024-02-29T12:00:00Z");
});

test("accepted UTC timestamps keep one to three fractional milliseconds and compare exactly", (t) => {
  const record = request();
  record.approval.approvedAt = "2026-10-01T12:00:00.9Z";
  record.delivery.exportedAt = "2026-10-01T12:00:01.0Z";
  const file = writeRecord(workspace(t), record);
  const result = run("--request", file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).recorded.approvedAt, "2026-10-01T12:00:00.9Z");
  expectRejected(t, (r) => {
    r.approval.approvedAt = "2026-10-01T12:00:00.9Z";
    r.delivery.exportedAt = "2026-10-01T12:00:00.5Z";
  }, [["EXPORT_BEFORE_APPROVAL", "approval.approvedAt"]]);
  expectRejected(t, (r) => { r.approval.approvedAt = "2026-10-01T12:00:00.9999Z"; }, [["INVALID_TIMESTAMP", "approval.approvedAt"]]);
});

test("oversized content is rejected by the bounded read even when stat underreports the file", (t) => {
  const root = workspace(t);
  fs.writeFileSync(path.join(root, "fs-mock.mjs"), FS_MOCK);
  fs.writeFileSync(path.join(root, "preload.mjs"), PRELOAD);
  const file = writeRecord(root, "x".repeat(128 * 1024 + 5), "grows.json");
  const preload = pathToFileURL(path.join(root, "preload.mjs")).href;
  const result = spawnSync(process.execPath, ["--import", preload, cli, "--request", file], {
    encoding: "utf8",
    env: { ...process.env, ASSET_GATE_FAKE_SIZE: "16" },
  });
  assert.equal(result.status, 1, result.stderr);
  assert.equal(result.stdout, "");
  assert.ok(result.stderr.startsWith("{"), result.stderr);
  assert.equal(JSON.parse(result.stderr).errors[0].code, "INPUT_TOO_LARGE");
});

test("the documented example stays a valid record", (t) => {
  const doc = fs.readFileSync(new URL("../docs/ASSET_MAP_PIPELINE.md", import.meta.url), "utf8");
  const block = [...doc.matchAll(/```json\n([\s\S]*?)```/g)]
    .map((match) => match[1])
    .find((text) => text.includes('"schema": "robloxia.asset-request/v1"'));
  assert.ok(block, "docs/ASSET_MAP_PIPELINE.md must contain a complete example record");
  const file = writeRecord(workspace(t), block);
  const result = run("--request", file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).status, "metadata_checks_passed");
});

test("help and strict argument handling never read, write or run anything else", (t) => {
  const root = workspace(t);
  const file = writeRecord(root, request());
  const before = fs.readFileSync(file);
  const help = run("--help");
  assert.equal(help.status, 0);
  assert.equal(help.stderr, "");
  assert.match(help.stdout, /--request <absolute-path>/);
  assert.match(help.stdout, /128 KiB/);
  assert.match(help.stdout, /authorization is always false/i);
  for (const args of [[], ["--request"], ["--request", file, "--request", file], ["--unknown", file], [file], ["--help", "--request", file]]) {
    const result = run(...args);
    assert.equal(result.status, 1, `args ${JSON.stringify(args)} must be rejected`);
    assert.equal(result.stdout, "");
    assert.equal(JSON.parse(result.stderr).errors[0].code, "USAGE");
  }
  const relative = run("--request", path.basename(file));
  assert.equal(relative.status, 1);
  assert.equal(JSON.parse(relative.stderr).errors[0].code, "ABSOLUTE_PATH_REQUIRED");
  assert.deepEqual(fs.readFileSync(file), before);
  assert.deepEqual(fs.readdirSync(root), ["request.json"]);
});

test("approval needs a recorded identity, a UTC time and every reference id exactly once", (t) => {
  expectRejected(t, (r) => { r.approval.approvedBy = "   "; }, [["INVALID_TEXT", "approval.approvedBy"]]);
  expectRejected(t, (r) => { delete r.approval.approvedAt; }, [["MISSING_FIELD", "approval.approvedAt"]]);
  expectRejected(t, (r) => { r.approval.approvedAt = "2026-10-01 12:00"; }, [["INVALID_TIMESTAMP", "approval.approvedAt"]]);
  expectRejected(t, (r) => { delete r.approval.referenceIds; }, [["MISSING_FIELD", "approval.referenceIds"]]);
  expectRejected(t, (r) => { r.approval.referenceIds = []; }, [["UNAPPROVED_REFERENCE", "references[0].id"]]);
  expectRejected(t, (r) => {
    r.references.push({ id: "ref-crate-concept-02", source: "vault://slime/concepts/crate-side.png", license: "project-owned", sha256: "b".repeat(64) });
  }, [["UNAPPROVED_REFERENCE", "references[1].id"]]);
  expectRejected(t, (r) => { r.approval.referenceIds.push("ref-missing-99"); }, [["DANGLING_APPROVAL_REFERENCE", "approval.referenceIds[1]"]]);
  expectRejected(t, (r) => { r.approval.referenceIds.push("ref-crate-concept-01"); }, [["DUPLICATE_APPROVAL_REFERENCE", "approval.referenceIds[1]"]]);
});

test("approval must predate the export and legacy creator manifests are not current approval", (t) => {
  expectRejected(t, (r) => { r.delivery.exportedAt = "2026-09-30T09:30:00Z"; }, [["EXPORT_BEFORE_APPROVAL", "approval.approvedAt"]]);
  const legacy = {
    batch: "zombies-v4",
    approvedBy: "creator",
    palateAtlas: "zombies_palette_256.png",
    totalAssets: 2,
    assets: [{ file: "zombie.glb" }],
  };
  expectRejected(t, (record) => {
    for (const key of Object.keys(record)) delete record[key];
    Object.assign(record, legacy);
  }, [
    ["MISSING_FIELD", "schema"], ["MISSING_FIELD", "assetId"], ["MISSING_FIELD", "references"],
  ], "legacy-assets-manifest.json");
});

test("reference provenance requires id, source, license and a lowercase SHA-256 digest", (t) => {
  expectRejected(t, (r) => { delete r.references[0].sha256; }, [["MISSING_FIELD", "references[0].sha256"]]);
  expectRejected(t, (r) => { r.references[0].sha256 = "abc123"; }, [["INVALID_SHA256", "references[0].sha256"]]);
  expectRejected(t, (r) => { r.references[0].sha256 = "A".repeat(64); }, [["INVALID_SHA256", "references[0].sha256"]]);
  expectRejected(t, (r) => { r.references[0].source = ""; }, [["INVALID_TEXT", "references[0].source"]]);
  expectRejected(t, (r) => { delete r.references[0].license; }, [["MISSING_FIELD", "references[0].license"]]);
  expectRejected(t, (r) => { r.references[0].id = "not a slug"; }, [["INVALID_ID", "references[0].id"]]);
  expectRejected(t, (r) => { r.references[0] = "vault://ref.png"; }, [["TYPE_INVALID", "references[0]"]]);
});

test("duplicate reference identifiers are rejected before any approval comparison", (t) => {
  expectRejected(t, (r) => {
    r.references.push({ ...r.references[0], source: "vault://slime/concepts/duplicate.png" });
    r.approval.referenceIds.push("ref-crate-concept-01");
  }, [["DUPLICATE_REFERENCE_ID", "references[1].id"]]);
});

test("unknown fields are rejected everywhere so metadata cannot widen the gate", (t) => {
  expectRejected(t, (r) => { r.authorized = true; }, [["UNKNOWN_FIELD", "authorized"]]);
  expectRejected(t, (r) => { r.approval.authorized = true; }, [["UNKNOWN_FIELD", "approval.authorized"]]);
  expectRejected(t, (r) => { r.delivery.humanApproved = true; }, [["UNKNOWN_FIELD", "delivery.humanApproved"]]);
  expectRejected(t, (r) => { r.budget.verified = true; }, [["UNKNOWN_FIELD", "budget.verified"]]);
  expectRejected(t, (r) => { r.references[0].approved = true; }, [["UNKNOWN_FIELD", "references[0].approved"]]);
});

test("asset kind and schema version are closed sets", (t) => {
  expectRejected(t, (r) => { r.schema = "robloxia.asset-request/v2"; }, [["SCHEMA_MISMATCH", "schema"]]);
  expectRejected(t, (r) => { r.assetKind = "blueprint"; }, [["INVALID_KIND", "assetKind"]]);
  expectRejected(t, (r) => { delete r.assetId; }, [["MISSING_FIELD", "assetId"]]);
  expectRejected(t, (r) => { r.assetId = "Slime Crate"; }, [["INVALID_ID", "assetId"]]);
});

test("mock, blocked, failed and draft deliveries never pass as exported assets", (t) => {
  for (const status of ["mock", "blocked", "failed", "draft", "planned"]) {
    expectRejected(t, (r) => { r.delivery.status = status; }, [["DELIVERY_NOT_ACCEPTED", "delivery.status"]]);
  }
  expectRejected(t, (r) => { r.delivery.evidence = ""; }, [["INVALID_TEXT", "delivery.evidence"]]);
  expectRejected(t, (r) => { r.delivery.exportedAt = 1759370000; }, [["TYPE_INVALID", "delivery.exportedAt"]]);
});

test("budget metrics must be finite, measured and inside the declared project limit", (t) => {
  expectRejected(t, (r) => { r.budget.measured = 20001; }, [["BUDGET_EXCEEDED", "budget.measured"]]);
  expectRejected(t, (r) => { r.budget.measured = -1; }, [["INVALID_NUMBER", "budget.measured"]]);
  expectRejected(t, (r) => { r.budget.limit = "20000"; }, [["TYPE_INVALID", "budget.limit"]]);
  expectRejected(t, (r) => { r.budget.evidence = ""; }, [["INVALID_TEXT", "budget.evidence"]]);
  expectRejected(t, (r) => { r.budget.metric = "studs"; }, [["INVALID_METRIC", "budget.metric"]]);
  const overflow = JSON.stringify(request(), null, 2).replace('"limit": 20000', '"limit": 1e999');
  expectRejectedRaw(t, overflow, [["INVALID_NUMBER", "budget.limit"]]);
});

test("command strings inside untrusted fields are recorded as data and never executed", (t) => {
  const root = workspace(t);
  const marker = path.join(root, "executed.txt");
  const payload = `$(node -e "require('fs').writeFileSync('${marker.replace(/\\/g, "\\\\")}','x')")`;
  const value = request();
  value.references[0].source = `vault://${payload}`;
  value.delivery.evidence = `node -e "require('fs').writeFileSync('${marker.replace(/\\/g, "\\\\")}','x')"`;
  value.budget.evidence = payload;
  const file = writeRecord(root, value);
  const result = run("--request", file);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, "");
  assert.equal(JSON.parse(result.stdout).authorization, false);
  assert.deepEqual(fs.readdirSync(root), ["request.json"]);
  assert.equal(fs.existsSync(marker), false, "embedded commands must never run");
});

test("input is one bounded regular JSON file, rejected before validation when unreadable", (t) => {
  const root = workspace(t);
  const cases = [
    [writeRecord(root, "x".repeat(128 * 1024 + 1), "oversized.json"), "INPUT_TOO_LARGE"],
    [writeRecord(root, "", "empty.json"), "EMPTY_INPUT"],
    [writeRecord(root, "{ not json", "broken.json"), "MALFORMED_JSON"],
    [writeRecord(root, "[]", "array.json"), "ROOT_NOT_OBJECT"],
    [writeRecord(root, "null", "null.json"), "ROOT_NOT_OBJECT"],
    [root, "INPUT_NOT_FILE"],
  ];
  for (const [file, code] of cases) {
    const result = run("--request", file);
    assert.equal(result.status, 1, `${code} expected`);
    assert.equal(result.stdout, "");
    assert.equal(JSON.parse(result.stderr).errors[0].code, code);
  }
  const missing = run("--request", path.join(root, "absent.json"));
  assert.equal(missing.status, 1);
  assert.equal(JSON.parse(missing.stderr).errors[0].code, "INPUT_NOT_FILE");
});
