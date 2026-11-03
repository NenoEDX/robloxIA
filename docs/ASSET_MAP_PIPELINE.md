# Asset and map pipeline

New assets require identified references and an explicit human approval before generation or
import. This document defines the request record, the read-only metadata check, and the map
phases with measurable acceptance gates. The check is bookkeeping only: it never generates,
imports, uploads, publishes, or certifies anything.

## Quick path

1. Write a short brief: purpose, asset kind, target game, scale and reuse constraints.
2. Record one reference per concept/image with an id, source, license and SHA-256 digest.
3. Ask the human to approve that exact set of references; record who, when and which ids.
4. Only after approval: prototype, export, and record the measured budget and evidence.
5. Run `node bridge/asset_reference_gate.mjs --request <absolute-path>` and fix every rejection.
6. Inspect the exported asset manually or in Studio, then ask separately for import/publication
   consent. A passing metadata report is not that consent.

## What the gate is and is not

| The gate does | The gate never does |
|---|---|
| Reads one JSON file you name, up to 128 KiB, with strict arguments | Read reference or evidence paths, follow URLs, or open exported files |
| Rejects unknown fields, duplicate reference ids, dangling approval ids and incomplete records | Execute commands found in fields; every field is untrusted data |
| Rejects mock/blocked/failed deliveries and over-budget or non-finite values | Write files, change configuration, upload, publish, or run plugins |
| Always reports `authorization: false`, `completion: "unverified"` and `manualInspection: "required"` | Verify claimed identity, hashes, licenses, measurements, or asset quality |

Metadata is not authority. A valid JSON record can be forged or hand-edited, so a passing
report means only that the metadata checks passed. Explicit live human consent is still
required before any generation, import, upload, or publication, even with a ready record.

## Record schema

The record uses `schema: "robloxia.asset-request/v1"`. All keys are required, unknown keys are
rejected, and all strings are untrusted text of at most 512 characters unless noted.

| Field | Rule |
|---|---|
| `assetId` | Lowercase slug matching `^[a-z][a-z0-9-]{2,63}$`. |
| `assetKind` | One of `mesh`, `texture`, `animation`, `audio`, `ui`, `vfx`. |
| `references[]` | 1-32 objects. Each needs `id` (slug), `source` (opaque URI/path, never read), `license` (at most 128 chars), and `sha256` (64 lowercase hex characters). |
| `approval.approvedBy` | Recorded reviewer identity, 1-200 characters. Recorded, not verified; the example name is fictional. |
| `approval.approvedAt` | UTC ISO-8601 with `Z`, e.g. `2026-10-01T12:00:00Z`. |
| `approval.referenceIds` | Every reference id exactly once, no duplicates, no unknown ids. |
| `delivery.status` | Must be `exported`; `mock`, `blocked`, `failed`, `draft`, or anything else is rejected. |
| `delivery.evidence` | Opaque pointer to the export or measurement record, never read. |
| `delivery.exportedAt` | UTC ISO-8601; must not precede `approval.approvedAt`. |
| `budget.metric` | One of `triangles`, `vertices`, `bytes`, `seconds`. |
| `budget.limit` | Finite positive number. Project-declared, never a universal engine limit. |
| `budget.measured` | Finite non-negative number, less than or equal to `limit`. |
| `budget.evidence` | Where the measurement came from, e.g. a mesher or profiler report. |

Add a metric or asset kind only by editing the CLI deliberately; a record cannot widen the enum
from inside JSON. Budgets are per project and per asset class: the repository's existing
per-mesh budget is 20,000 triangles (`AGENTS.md`), but the gate does not invent or enforce a
global Roblox limit.

## Complete example

```json
{
  "schema": "robloxia.asset-request/v1",
  "assetId": "slime-crate-proto-01",
  "assetKind": "mesh",
  "references": [
    {
      "id": "ref-crate-concept-01",
      "source": "vault://slime/concepts/crate-front.png",
      "license": "project-owned",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  ],
  "approval": {
    "approvedBy": "fictional-reviewer-placeholder",
    "approvedAt": "2026-10-01T12:00:00Z",
    "referenceIds": ["ref-crate-concept-01"]
  },
  "delivery": {
    "status": "exported",
    "evidence": "exports/slime/crate.glb",
    "exportedAt": "2026-10-02T09:30:00Z"
  },
  "budget": {
    "metric": "triangles",
    "limit": 20000,
    "measured": 12345,
    "evidence": "blender validate_mesh_budget report"
  }
}
```

## Running the check

```bash
node bridge/asset_reference_gate.mjs --request "C:/work/assets/slime-crate-proto-01.json"
node bridge/asset_reference_gate.mjs --help
```

A passing record exits 0 and prints one JSON line whose important fields are:

```json
{
  "status": "metadata_checks_passed",
  "authorization": false,
  "completion": "unverified",
  "manualInspection": "required",
  "notGranted": ["human_approval", "asset_generation", "asset_import", "asset_upload", "publication", "quality_certification"]
}
```

A rejected record exits 1, prints nothing on stdout, and prints JSON on stderr with
`status: "rejected"` and an `errors` array of `{ code, path }`. Common codes:

| Code | Meaning |
|---|---|
| `USAGE`, `ABSOLUTE_PATH_REQUIRED` | Wrong arguments, or the record path is not absolute. |
| `INPUT_NOT_FILE`, `EMPTY_INPUT`, `INPUT_TOO_LARGE`, `MALFORMED_JSON`, `ROOT_NOT_OBJECT` | The single input is not a bounded regular JSON object file. |
| `UNKNOWN_FIELD`, `MISSING_FIELD`, `TYPE_INVALID`, `INVALID_TEXT` | The record does not match the closed schema. |
| `INVALID_ID`, `INVALID_KIND`, `SCHEMA_MISMATCH`, `INVALID_TIMESTAMP` | A closed value or format is wrong. |
| `INVALID_SHA256` | Reference provenance is not a lowercase SHA-256 digest. |
| `DUPLICATE_REFERENCE_ID`, `DUPLICATE_APPROVAL_REFERENCE`, `DANGLING_APPROVAL_REFERENCE`, `UNAPPROVED_REFERENCE` | Reference/approval scoping is inconsistent. |
| `EXPORT_BEFORE_APPROVAL`, `DELIVERY_NOT_ACCEPTED` | The delivery violates approval order or is a mock/blocked/failed state. |
| `INVALID_METRIC`, `INVALID_NUMBER`, `BUDGET_EXCEEDED`, `LIMIT_EXCEEDED` | Budget values are invalid, over the declared limit, or the record exceeds size/count limits. |

Known limitations: duplicate JSON keys are resolved by `JSON.parse` keeping the last value, and
the digest in the report covers the record file, not the referenced assets. The record is read
through a fixed 128 KiB + 1 byte buffer, so growth after the size check still ends in
`INPUT_TOO_LARGE` rather than an unbounded read.

## Approval scope and invalidation

Approval covers the exact reference ids, licenses and sources recorded at approval time. Any
change to a reference source, license, digest, or the approved id set invalidates the approval:
record a new human approval before generating or importing again. Old batch manifests, such as
an `assets_manifest.json` with `approvedBy: "creator"` and no reference provenance, remain
project history. They are not retroactively certified and are rejected by this schema; do not
rewrite them to look approved.

## Map and level pipeline

Maps follow the same rule: no new visual asset is generated before S5 approval. Each phase needs
recorded evidence before the next starts; a later phase never retroactively blesses an earlier
one.

| Phase | Deliverable | Acceptance gate |
|---|---|---|
| 1. Approved layout | Reference board, scale plan, traversal and combat intent | Human approved the reference set and layout brief |
| 2. Playable blockout | Grey-box geometry with spawns, routes and objectives | Real playtest: reachable objectives, no soft-locks, intent visible |
| 3. Modular kit | Grid, pivot and collision conventions for reusable pieces | Documented stud grid; pivots and collision hulls measured and spot-checked |
| 4. Art pass | Approved assets placed on the proven blockout | Every asset has an approved record and passes the metadata gate |
| 5. Device verification | Traversal, combat, streaming and performance measurements | Project-specific budgets met on target devices, with recorded probes/screenshots |

Measurements must come from the real build on real target devices. Desktop-only screenshots,
mock data, and remembered results from an earlier session are not passing evidence. Record the
device, build, date and the probe or capture that produced each number, then keep that evidence
next to the map until the next change invalidates it.

## Checklist

- [ ] Brief and reference ids are recorded before any generation.
- [ ] A human approved this exact reference set, identity and UTC time recorded.
- [ ] License and SHA-256 provenance exist for every reference.
- [ ] Export exists and its declared measurement is within the project budget.
- [ ] Metadata gate passes, and the report still says authorization false and completion unverified.
- [ ] Manual or Studio inspection is done, and import/publication consent is requested separately.
- [ ] Legacy manifests are left untouched as history.
