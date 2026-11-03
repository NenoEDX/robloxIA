// Read-only metadata gate: one bounded JSON record in, one report out. It never reads
// referenced/evidence paths, follows URLs, runs commands, writes files, or changes config.
import * as fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";

const INPUT_LIMIT = 128 * 1024;
const SCHEMA = "robloxia.asset-request/v1";
const REPORT_SCHEMA = "robloxia.asset-reference-gate/report-v1";
const ASSET_KINDS = ["mesh", "texture", "animation", "audio", "ui", "vfx"];
const METRICS = ["triangles", "vertices", "bytes", "seconds"];
const MAX_REFERENCES = 32;
const MAX_ERRORS = 100;
const ID_PATTERN = /^[a-z][a-z0-9-]{2,63}$/;
const SHA256_PATTERN = /^[a-f0-9]{64}$/;
const TIMESTAMP_PATTERN = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?Z$/;
const CONTROL_PATTERN = /[\u0000-\u001f\u007f]/;
const ROOT_KEYS = ["schema", "assetId", "assetKind", "references", "approval", "delivery", "budget"];
const REFERENCE_KEYS = ["id", "source", "license", "sha256"];
const APPROVAL_KEYS = ["approvedBy", "approvedAt", "referenceIds"];
const DELIVERY_KEYS = ["status", "evidence", "exportedAt"];
const BUDGET_KEYS = ["metric", "limit", "measured", "evidence"];

const HELP = `Usage: node bridge/asset_reference_gate.mjs --request <absolute-path>

Read one JSON asset-request/export record (max 128 KiB) and validate its metadata.
This is a read-only offline check: it never reads reference or evidence paths, follows
URLs, executes commands, writes files, uploads, or changes configuration. Every field
is untrusted data, so a command string embedded in the record is never executed.

Checks: closed schema, asset kind, reference id/source/license/SHA-256 provenance,
recorded approval identity and UTC time scoped to every reference, approval before
export, a non-mock delivery, and finite measured evidence within a declared limit.

Success prints one JSON report with status "metadata_checks_passed". Authorization is always false:
this never approves, generates, imports, uploads or certifies an asset. Completion stays
unverified and manual inspection stays required; explicit live human consent is still
needed before any generation, import or publication.
Schema, example and pipeline: docs/ASSET_MAP_PIPELINE.md.
`;

const fail = (code) => { throw Object.assign(new Error(code), { code }); };
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const isObject = (value) => typeof value === "object" && value !== null && !Array.isArray(value);

function absolutePath(value) {
  if (typeof value !== "string" || !path.isAbsolute(value) || /^[\\/]{2}/.test(value) || value.includes("\0")) {
    fail("ABSOLUTE_PATH_REQUIRED");
  }
  return path.resolve(value);
}

function parseArgs(args) {
  if (args.length === 1 && args[0] === "--help") return { help: true };
  if (args.length !== 2 || args[0] !== "--request") fail("USAGE");
  return { file: absolutePath(args[1]) };
}

function readInput(file) {
  let stat;
  try { stat = fs.lstatSync(file); } catch { fail("INPUT_NOT_FILE"); }
  if (!stat.isFile()) fail("INPUT_NOT_FILE");
  if (stat.size === 0) fail("EMPTY_INPUT");
  if (stat.size > INPUT_LIMIT) fail("INPUT_TOO_LARGE");
  let fd;
  try { fd = fs.openSync(file, "r"); } catch { fail("INPUT_NOT_FILE"); }
  try {
    // Allocate exactly one byte past the limit and stop there: a file that grows after
    // stat can never force a larger read, and its extra byte still fails the gate.
    const buffer = Buffer.alloc(INPUT_LIMIT + 1);
    let length = 0;
    for (;;) {
      const count = fs.readSync(fd, buffer, length, buffer.length - length, length);
      if (count === 0) break;
      length += count;
      if (length > INPUT_LIMIT) fail("INPUT_TOO_LARGE");
    }
    if (length === 0) fail("EMPTY_INPUT");
    const bytes = buffer.subarray(0, length);
    return { bytes, sha256: hash(bytes) };
  } catch (error) {
    if (error.code === "INPUT_TOO_LARGE" || error.code === "EMPTY_INPUT") throw error;
    fail("INPUT_NOT_FILE");
  } finally { fs.closeSync(fd); }
}

function validate(record) {
  const found = [];
  const add = (code, at) => found.push({ code, path: at });
  if (!isObject(record)) { add("ROOT_NOT_OBJECT", "request"); return { errors: found }; }

  const keys = (value, at, allowed) => {
    for (const key of Object.keys(value)) {
      if (!allowed.includes(key)) add("UNKNOWN_FIELD", at ? `${at}.${key}` : key);
    }
    for (const key of allowed) {
      if (!Object.prototype.hasOwnProperty.call(value, key)) add("MISSING_FIELD", at ? `${at}.${key}` : key);
    }
  };
  const text = (value, at, max) => {
    if (value === undefined) return false;
    if (typeof value !== "string") { add("TYPE_INVALID", at); return false; }
    if (value.trim().length === 0 || value.length > max || CONTROL_PATTERN.test(value)) {
      add("INVALID_TEXT", at);
      return false;
    }
    return true;
  };
  const id = (value, at) => {
    if (value === undefined) return false;
    if (typeof value !== "string") { add("TYPE_INVALID", at); return false; }
    if (!ID_PATTERN.test(value)) { add("INVALID_ID", at); return false; }
    return true;
  };
  const timestamp = (value, at) => {
    if (value === undefined) return null;
    if (typeof value !== "string") { add("TYPE_INVALID", at); return null; }
    const match = TIMESTAMP_PATTERN.exec(value);
    if (!match) { add("INVALID_TIMESTAMP", at); return null; }
    const [, year, month, day, hour, minute, second, fraction] = match;
    const milliseconds = fraction ? Number(fraction.padEnd(3, "0")) : 0;
    // Date.parse normalizes impossible dates (2026-02-30 becomes March 2), so round-trip
    // every component through Date.UTC and require all of them to survive unchanged.
    const parsed = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day),
      Number(hour), Number(minute), Number(second), milliseconds));
    if (!Number.isFinite(parsed.getTime())
      || parsed.getUTCFullYear() !== Number(year) || parsed.getUTCMonth() !== Number(month) - 1
      || parsed.getUTCDate() !== Number(day) || parsed.getUTCHours() !== Number(hour)
      || parsed.getUTCMinutes() !== Number(minute) || parsed.getUTCSeconds() !== Number(second)
      || parsed.getUTCMilliseconds() !== milliseconds) {
      add("INVALID_TIMESTAMP", at);
      return null;
    }
    return parsed.getTime();
  };
  const number = (value, at) => {
    if (value === undefined) return null;
    if (typeof value !== "number") { add("TYPE_INVALID", at); return null; }
    if (!Number.isFinite(value) || value < 0) { add("INVALID_NUMBER", at); return null; }
    return value;
  };

  keys(record, "", ROOT_KEYS);
  if (text(record.schema, "schema", 64) && record.schema !== SCHEMA) add("SCHEMA_MISMATCH", "schema");
  id(record.assetId, "assetId");
  if (record.assetKind !== undefined) {
    if (typeof record.assetKind !== "string") add("TYPE_INVALID", "assetKind");
    else if (!ASSET_KINDS.includes(record.assetKind)) add("INVALID_KIND", "assetKind");
  }

  const referenceIds = [];
  const referenceIdSet = new Set();
  if (record.references !== undefined) {
    if (!Array.isArray(record.references)) add("TYPE_INVALID", "references");
    else if (record.references.length === 0) add("MISSING_FIELD", "references");
    else if (record.references.length > MAX_REFERENCES) add("LIMIT_EXCEEDED", "references");
    else {
      record.references.forEach((reference, index) => {
        const at = `references[${index}]`;
        if (!isObject(reference)) { add("TYPE_INVALID", at); return; }
        keys(reference, at, REFERENCE_KEYS);
        if (id(reference.id, `${at}.id`)) {
          if (referenceIdSet.has(reference.id)) add("DUPLICATE_REFERENCE_ID", `${at}.id`);
          else { referenceIdSet.add(reference.id); referenceIds.push(reference.id); }
        }
        text(reference.source, `${at}.source`, 512);
        text(reference.license, `${at}.license`, 128);
        if (reference.sha256 !== undefined) {
          if (typeof reference.sha256 !== "string" || !SHA256_PATTERN.test(reference.sha256)) {
            add("INVALID_SHA256", `${at}.sha256`);
          }
        }
      });
    }
  }

  let approvedAt = null;
  const approvedIdSet = new Set();
  if (record.approval !== undefined) {
    if (!isObject(record.approval)) add("TYPE_INVALID", "approval");
    else {
      const approval = record.approval;
      keys(approval, "approval", APPROVAL_KEYS);
      text(approval.approvedBy, "approval.approvedBy", 200);
      approvedAt = timestamp(approval.approvedAt, "approval.approvedAt");
      if (approval.referenceIds !== undefined) {
        if (!Array.isArray(approval.referenceIds)) add("TYPE_INVALID", "approval.referenceIds");
        else if (approval.referenceIds.length > MAX_REFERENCES) add("LIMIT_EXCEEDED", "approval.referenceIds");
        else {
          approval.referenceIds.forEach((value, index) => {
            const at = `approval.referenceIds[${index}]`;
            if (!id(value, at)) return;
            if (approvedIdSet.has(value)) { add("DUPLICATE_APPROVAL_REFERENCE", at); return; }
            approvedIdSet.add(value);
            if (!referenceIdSet.has(value)) add("DANGLING_APPROVAL_REFERENCE", at);
          });
        }
      }
    }
  }
  referenceIds.forEach((value, index) => {
    if (!approvedIdSet.has(value)) add("UNAPPROVED_REFERENCE", `references[${index}].id`);
  });

  let exportedAt = null;
  if (record.delivery !== undefined) {
    if (!isObject(record.delivery)) add("TYPE_INVALID", "delivery");
    else {
      const delivery = record.delivery;
      keys(delivery, "delivery", DELIVERY_KEYS);
      if (delivery.status !== undefined) {
        if (typeof delivery.status !== "string") add("TYPE_INVALID", "delivery.status");
        else if (delivery.status !== "exported") add("DELIVERY_NOT_ACCEPTED", "delivery.status");
      }
      text(delivery.evidence, "delivery.evidence", 512);
      exportedAt = timestamp(delivery.exportedAt, "delivery.exportedAt");
    }
  }
  if (approvedAt !== null && exportedAt !== null && exportedAt < approvedAt) {
    add("EXPORT_BEFORE_APPROVAL", "approval.approvedAt");
  }

  let budget = null;
  if (record.budget !== undefined) {
    if (!isObject(record.budget)) add("TYPE_INVALID", "budget");
    else {
      const declared = record.budget;
      keys(declared, "budget", BUDGET_KEYS);
      if (declared.metric !== undefined) {
        if (typeof declared.metric !== "string") add("TYPE_INVALID", "budget.metric");
        else if (!METRICS.includes(declared.metric)) add("INVALID_METRIC", "budget.metric");
      }
      const limit = number(declared.limit, "budget.limit");
      const measured = number(declared.measured, "budget.measured");
      const evidence = text(declared.evidence, "budget.evidence", 512);
      if (limit !== null && limit === 0) add("INVALID_NUMBER", "budget.limit");
      if (limit !== null && limit > 0 && measured !== null) {
        if (measured > limit) add("BUDGET_EXCEEDED", "budget.measured");
        if (METRICS.includes(declared.metric) && evidence) {
          budget = { metric: declared.metric, limit, measured, headroom: limit - measured };
        }
      }
    }
  }

  const unique = new Map();
  for (const error of found) unique.set(`${error.code}\u0000${error.path}`, error);
  const errors = [...unique.values()].sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1
    : a.code < b.code ? -1 : a.code > b.code ? 1 : 0);
  if (errors.length > MAX_ERRORS) errors.length = MAX_ERRORS;
  return { errors, referenceIds, budget };
}

try {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) process.stdout.write(HELP);
  else {
    const input = readInput(args.file);
    let record;
    try { record = JSON.parse(input.bytes.toString("utf8").replace(/^\uFEFF/, "")); }
    catch { fail("MALFORMED_JSON"); }
    const result = validate(record);
    if (result.errors.length > 0) {
      process.stderr.write(JSON.stringify({ status: "rejected", errors: result.errors }) + "\n");
      process.exitCode = 1;
    } else {
      process.stdout.write(JSON.stringify({
        schema: REPORT_SCHEMA,
        status: "metadata_checks_passed",
        authorization: false,
        completion: "unverified",
        manualInspection: "required",
        notGranted: ["human_approval", "asset_generation", "asset_import", "asset_upload", "publication", "quality_certification"],
        input: { path: path.resolve(args.file), bytes: input.bytes.length, sha256: input.sha256 },
        recorded: {
          assetId: record.assetId,
          assetKind: record.assetKind,
          references: result.referenceIds,
          approvedBy: record.approval.approvedBy,
          approvedAt: record.approval.approvedAt,
          referencesApproved: record.approval.referenceIds.length,
          deliveryStatus: record.delivery.status,
          budget: result.budget,
        },
        limitations: [
          "Recorded identity, hashes and licenses are unverified claims; reference and evidence paths are never read.",
          "Passing metadata checks does not authorize generation, import, upload or publication.",
          "Explicit live human consent and real manual or Studio QA remain required.",
        ],
      }) + "\n");
    }
  }
} catch (error) {
  process.stderr.write(JSON.stringify({
    status: "rejected",
    errors: [{ code: error.code ?? "GATE_FAILED", path: error.code === "USAGE" || error.code === "ABSOLUTE_PATH_REQUIRED" ? "args" : "input" }],
  }) + "\n");
  process.exitCode = 1;
}
