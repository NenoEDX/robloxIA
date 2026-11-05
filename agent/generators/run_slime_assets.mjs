// @ts-check
/**
 * run_slime_assets.mjs — build and verify the S13 reference-led slime asset pack.
 *
 * The heavy lifting lives in agent/generators/blender/build_slime_assets.py, which
 * runs inside Blender 5.2. This runner owns argument handling, per-model execution,
 * artifact validation (real GLB/PNG parsing, never source substrings) and the
 * pack manifest/handoff report.
 *
 * Usage:
 *   node agent/generators/run_slime_assets.mjs --list
 *   node agent/generators/run_slime_assets.mjs --all --out exports/slime-v1
 *   node agent/generators/run_slime_assets.mjs --only classic_blue --out exports/slime-v1
 *   node agent/generators/run_slime_assets.mjs --all --out <dir> --dry-run
 *
 * Options:
 *   --list                 Print the 13 design contracts and exit (no writes).
 *   --all                  Build every design listed in slime_specs/manifest.json.
 *   --only a,b             Build only the named designs.
 *   --out <dir>            Required with --all/--only. Created only when building.
 *   --blender <exe>        Blender executable (default: BLENDER_BIN or Blender 5.2 path).
 *   --skip-render          Skip preview/silhouette renders (faster structural pass).
 *   --dry-run              Print the Blender commands without running them.
 *   --help                 Print this usage.
 *
 * Output layout: <out>/<slug>/<slug>.{blend,glb}, <slug>_{color,roughness,preview,silhouette}.png,
 * <slug>_stats.json, plus <out>/manifest.json and <out>/ASSETS_HANDOFF.md.
 *
 * Exit codes: 0 success, 1 generation/validation failure, 2 usage error.
 */

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");
const BUILDER = path.join(HERE, "blender", "build_slime_assets.py");
const SPEC_DIR = path.join(HERE, "blender", "slime_specs");
const HELPER = path.join(REPO, "skills-roblox", "roblox-36-asset-pipeline", "scripts", "blender_export_example.py");
const DEFAULT_BLENDER = process.env.BLENDER_BIN || "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe";

const CLIP_NAMES = ["Idle", "Extract", "Release"];
const USAGE = [
  "usage: node agent/generators/run_slime_assets.mjs --list",
  "       node agent/generators/run_slime_assets.mjs (--all | --only a,b) --out <dir> [--blender <exe>] [--skip-render] [--dry-run]",
].join("\n");

/** @param {string} message */
function fail(message) {
  console.error(`[slime-assets] ERROR: ${message}`);
  console.error(USAGE);
  process.exit(2);
}

/** @param {string} message */
function abort(message) {
  console.error(`[slime-assets] ERROR: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  /** @type {{list:boolean,all:boolean,only:string[]|null,out:string|null,blender:string,skipRender:boolean,dryRun:boolean,help:boolean}} */
  const args = {
    list: false,
    all: false,
    only: null,
    out: null,
    blender: DEFAULT_BLENDER,
    skipRender: false,
    dryRun: false,
    help: false,
  };
  for (let index = 2; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--list") args.list = true;
    else if (flag === "--all") args.all = true;
    else if (flag === "--skip-render") args.skipRender = true;
    else if (flag === "--dry-run") args.dryRun = true;
    else if (flag === "--help" || flag === "-h") args.help = true;
    else if (["--only", "--out", "--blender"].includes(flag)) {
      const value = argv[++index];
      if (!value || value.startsWith("--")) fail(`${flag} requires a value`);
      if (flag === "--only") args.only = value.split(",").map((item) => item.trim()).filter(Boolean);
      else if (flag === "--out") args.out = value;
      else args.blender = value;
    } else fail(`unknown flag: ${flag}`);
  }
  if (args.help) return args;
  const modes = [args.list, args.all, args.only !== null].filter(Boolean).length;
  if (modes > 1) fail("choose exactly one of --list, --all or --only");
  if (!args.list) {
    if (!args.all && args.only === null) fail("missing design selection: pass --all or --only <slugs>");
    if (!args.out) fail("missing --out <dir> for a generation run");
  }
  return args;
}

function loadPack() {
  const manifestPath = path.join(SPEC_DIR, "manifest.json");
  if (!fs.existsSync(manifestPath)) abort(`missing pack manifest: ${manifestPath}`);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const slugs = manifest.designs;
  if (!Array.isArray(slugs) || slugs.length !== 13) abort("slime_specs/manifest.json must list exactly 13 designs");
  const designs = slugs.map((slug) => {
    const specPath = path.join(SPEC_DIR, `${slug}.json`);
    if (!fs.existsSync(specPath)) abort(`missing spec for design ${slug}: ${specPath}`);
    const spec = JSON.parse(fs.readFileSync(specPath, "utf8"));
    if (spec.slug !== slug) abort(`spec ${slug}.json declares slug "${spec.slug}"`);
    return { slug, specPath, spec };
  });
  return { manifest, designs };
}

/** @param {string} file */
function blobSha256(file) {
  return createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

/** Read the JSON chunk of a binary glTF container. */
function readGlbJson(file) {
  const buffer = fs.readFileSync(file);
  const errors = [];
  if (buffer.length < 20) return { errors: ["GLB shorter than a header"], doc: null };
  if (buffer.readUInt32LE(0) !== 0x46546c67) errors.push("bad GLB magic");
  if (buffer.readUInt32LE(4) !== 2) errors.push(`unsupported GLB version ${buffer.readUInt32LE(4)}`);
  if (buffer.readUInt32LE(8) !== buffer.length) errors.push("GLB declared length does not match the file");
  const jsonLength = buffer.readUInt32LE(12);
  if (buffer.readUInt32LE(16) !== 0x4e4f534a) errors.push("first GLB chunk is not JSON");
  if (20 + jsonLength > buffer.length) return { errors: [...errors, "truncated JSON chunk"], doc: null };
  try {
    return { errors, doc: JSON.parse(buffer.subarray(20, 20 + jsonLength).toString("utf8")) };
  } catch (error) {
    return { errors: [...errors, `unreadable JSON chunk: ${error.message}`], doc: null };
  }
}

function pngSize(file) {
  const buffer = fs.readFileSync(file);
  if (buffer.length < 24 || buffer.readUInt32BE(0) !== 0x89504e47) return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}

/** Validate the real artifacts of one generated design. */
function validateDesign(slug, spec, directory, skipRender) {
  const errors = [];
  const files = {
    glb: path.join(directory, `${slug}.glb`),
    blend: path.join(directory, `${slug}.blend`),
    color: path.join(directory, `${slug}_color.png`),
    roughness: path.join(directory, `${slug}_roughness.png`),
    preview: path.join(directory, `${slug}_preview.png`),
    silhouette: path.join(directory, `${slug}_silhouette.png`),
    stats: path.join(directory, `${slug}_stats.json`),
  };
  for (const key of ["glb", "blend", "color", "roughness", "stats"]) {
    if (!fs.existsSync(files[key])) errors.push(`missing ${path.basename(files[key])}`);
  }
  if (errors.length) return { errors, files, metrics: null };

  let stats = null;
  try {
    stats = JSON.parse(fs.readFileSync(files.stats, "utf8"));
  } catch (error) {
    errors.push(`unreadable stats: ${error.message}`);
  }
  if (stats) {
    if (stats.slug !== slug) errors.push("stats slug mismatch");
    if (!(stats.tris > 0 && stats.tris < 20000)) errors.push(`triangle budget: ${stats.tris}`);
    if (stats.nonFinite !== 0) errors.push(`non-finite geometry: ${stats.nonFinite}`);
    if (!(stats.rig?.maxInfluences <= 4)) errors.push(`influences: ${stats.rig?.maxInfluences}`);
    if (!(stats.rig?.maxWeightError < 1e-4)) errors.push(`weight normalisation: ${stats.rig?.maxWeightError}`);
    if (!(stats.loopError < 1e-4)) errors.push(`idle loop error: ${stats.loopError}`);
    if (Math.abs(stats.origin?.bottomZ ?? 99) > 1e-3) errors.push("origin is not at the bottom");
    if (!(stats.uv?.minU >= -1e-4 && stats.uv?.maxU <= 1 + 1e-4)) errors.push("UV U outside 0-1");
    if (!(stats.uv?.minV >= -1e-4 && stats.uv?.maxV <= 1 + 1e-4)) errors.push("UV V outside 0-1");
    const names = (stats.clips ?? []).map((clip) => clip.name);
    if (names.join(",") !== CLIP_NAMES.join(",")) errors.push(`clip list: ${names.join(",") || "none"}`);
    for (const clip of stats.clips ?? []) {
      if (!(clip.channels > 0)) errors.push(`${clip.name}: no animated channels`);
      if (!(clip.frames >= 24)) errors.push(`${clip.name}: too short`);
    }
    for (const key of ["triangleBudget", "normalizedWeights", "uvInRange", "bottomOrigin", "clipCount", "loopIdentity", "texturesEmbedded", "blendTexturesPacked", "quaternionContinuity"]) {
      if (stats.checks?.[key] !== true) errors.push(`check ${key} failed`);
    }
    for (const file of [files.color, files.roughness]) {
      const size = pngSize(file);
      if (!size) errors.push(`${path.basename(file)} is not a PNG`);
      else if (size.width !== spec.textureSize || size.height !== spec.textureSize) {
        errors.push(`${path.basename(file)} is ${size.width}x${size.height}, expected ${spec.textureSize}`);
      }
    }
  }

  const { doc, errors: glbErrors } = readGlbJson(files.glb);
  errors.push(...glbErrors);
  let clipNames = [];
  if (doc) {
    if (doc.meshes?.length !== 1) errors.push(`expected 1 merged mesh, found ${doc.meshes?.length ?? 0}`);
    for (const mesh of doc.meshes ?? []) {
      for (const primitive of mesh.primitives ?? []) {
        for (const attribute of ["POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"]) {
          if (!(attribute in (primitive.attributes ?? {}))) errors.push(`primitive missing ${attribute}`);
        }
      }
    }
    if (doc.skins?.length !== 1) errors.push(`expected 1 skin, found ${doc.skins?.length ?? 0}`);
    else if (!(doc.skins[0].joints?.length >= 3)) errors.push("skin has too few joints");
    clipNames = (doc.animations ?? []).map((animation) => animation.name).sort();
    if (clipNames.join(",") !== [...CLIP_NAMES].sort().join(",")) errors.push(`GLB clips: ${clipNames.join(",")}`);
    for (const animation of doc.animations ?? []) {
      if (!(animation.channels?.length > 0)) errors.push(`${animation.name}: empty channels`);
      if (!(animation.samplers?.length > 0)) errors.push(`${animation.name}: empty samplers`);
    }
    if (!(doc.images?.length >= 2)) errors.push(`GLB embeds ${doc.images?.length ?? 0} images, expected 2`);
    for (const image of doc.images ?? []) {
      if (!Number.isInteger(image.bufferView)) errors.push("texture is not embedded in the GLB");
    }
    const pbr = doc.materials?.[0]?.pbrMetallicRoughness ?? {};
    if (!pbr.baseColorTexture) errors.push("material has no base colour texture");
    if (!pbr.metallicRoughnessTexture) errors.push("material has no roughness texture");
    for (const accessor of (doc.meshes ?? [])
      .flatMap((mesh) => mesh.primitives ?? [])
      .map((primitive) => doc.accessors?.[primitive.attributes?.POSITION])) {
      for (const value of [...(accessor?.min ?? []), ...(accessor?.max ?? [])]) {
        if (!Number.isFinite(value)) errors.push("non-finite GLB position bound");
      }
    }
  }

  for (const key of ["preview", "silhouette"]) {
    if (!fs.existsSync(files[key]) && !skipRender) errors.push(`missing ${path.basename(files[key])}`);
  }

  const metrics = stats
    ? {
        tris: stats.tris,
        vertices: stats.vertices,
        bones: stats.rig?.deformBones ?? 0,
        bounds: stats.bounds?.size ?? null,
        clips: (stats.clips ?? []).map((clip) => ({ name: clip.name, frames: clip.frames, seconds: clip.durationSeconds })),
        loopError: stats.loopError,
        textureSize: spec.textureSize,
      }
    : null;

  return { errors, files, metrics, clipNames };
}

function probeBlender(bin) {
  const probe = spawnSync(bin, ["--version"], { encoding: "utf8" });
  if (probe.error || probe.status !== 0) return null;
  return String(probe.stdout || "").split(/\r?\n/)[0].trim();
}

function buildOne(args, design, outDir) {
  const slugDir = path.join(outDir, design.slug);
  const command = [
    args.blender,
    "--background",
    "--factory-startup",
    "--python-exit-code",
    "1",
    "--python",
    BUILDER,
    "--",
    "--spec",
    design.specPath,
    "--out",
    slugDir,
    "--helper",
    HELPER,
    "--seed",
    String(1000 + design.slug.length * 7),
  ];
  if (args.skipRender) command.push("--skip-render");
  if (args.dryRun) {
    console.log(`[dry-run] build=${design.slug} ${command.map((part) => (part.includes(" ") ? `"${part}"` : part)).join(" ")}`);
    return { status: "planned" };
  }
  fs.mkdirSync(slugDir, { recursive: true });
  console.log(`[slime-assets] building ${design.slug} ...`);
  const run = spawnSync(command[0], command.slice(1), {
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024,
    env: { ...process.env, PYTHONPYCACHEPREFIX: path.join(os.tmpdir(), "slime-assets-pycache") },
  });
  if (run.status !== 0) {
    const tail = String(run.stderr || "").split(/\r?\n/).filter(Boolean).slice(-8).join("\n");
    const head = String(run.stdout || "").split(/\r?\n/).filter(Boolean).slice(-8).join("\n");
    console.error(`[slime-assets] ${design.slug}: Blender exited ${run.status}`);
    if (head) console.error(head);
    if (tail) console.error(tail);
    return { status: "failed", error: `Blender exit ${run.status}` };
  }
  return { status: "built" };
}

function writeReports(outDir, reports, blenderInfo, args) {
  const manifest = {
    schema: "robloxia.slime-asset-pack-run/v1",
    pack: "slime-v1",
    blender: blenderInfo,
    skipRender: args.skipRender,
    generatedAt: new Date().toISOString(),
    contract: {
      units: "1 Blender unit = 1 Roblox stud",
      origin: "bottom-center",
      forward: "-Y in Blender; glTF becomes +Z after the Y-up conversion",
      clips: CLIP_NAMES,
      textureSize: "per design (1024)",
    },
    designs: reports,
  };
  fs.writeFileSync(path.join(outDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");

  const lines = [];
  lines.push("# SLIME PIT — slime-v1 asset handoff");
  lines.push("");
  lines.push(`> Blender: ${blenderInfo}`);
  lines.push(`> Generated: ${manifest.generatedAt}`);
  lines.push("> Local edits are authorized; Roblox import, upload and playback remain separate proof through official MCP only.");
  lines.push("> References were read-only inputs and are not redistributed with this pack.");
  lines.push("");
  lines.push("## Contract");
  lines.push("");
  lines.push("- Scale: 1 Blender unit = 1 Roblox stud.");
  lines.push("- Origin: bottom-center (min Z = 0, XY centred).");
  lines.push("- Forward: -Y in Blender.");
  lines.push("- Every model: one merged mesh, one skin, embedded 1024 colour + roughness textures, three clips `Idle`, `Extract`, `Release`.");
  lines.push("");
  lines.push("## Designs");
  lines.push("");
  lines.push("| slug | design | ref | height (studs) | tris | bones | clips | files |");
  lines.push("|---|---|---|---|---|---|---|---|");
  for (const report of reports) {
    const height = report.bounds ? Number(report.bounds[2]).toFixed(2) : "—";
    const clips = report.clips ? report.clips.map((clip) => `${clip.name}(${clip.frames}f)`).join(" ") : "—";
    const files = report.status === "ok" ? `\`${report.slug}.glb\`, \`${report.slug}.blend\`, preview` : "—";
    lines.push(`| \`${report.slug}\` | ${report.name} | \`${report.referenceFile}\` | ${height} | ${report.tris ?? "—"} | ${report.bones ?? "—"} | ${clips} | ${files} |`);
  }
  lines.push("");
  lines.push("## Not proven here");
  lines.push("");
  lines.push("- Studio import, animation playback and Roblox-side VFX are untested by this pack.");
  lines.push("- No mesh, texture, animation or sound asset id is published or fabricated.");
  lines.push("- Catalog/rarity binding is intentionally absent; the asset slugs are design identities only.");
  lines.push("");
  fs.writeFileSync(path.join(outDir, "ASSETS_HANDOFF.md"), lines.join("\n"), "utf8");
}

function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    console.log(USAGE);
    return;
  }
  const { designs } = loadPack();

  if (args.list) {
    const rows = designs.map(({ slug, spec }) => [
      slug,
      spec.name,
      `height=${spec.heightStuds.toFixed(1)}`,
      `ref=${spec.referenceFile}`,
    ]);
    console.log("SLIME_ASSET_PACK v1");
    console.log(`designs=${designs.length}`);
    for (const row of rows) console.log(row.join("\t"));
    console.log(`clips=${CLIP_NAMES.join(",")}`);
    return;
  }

  if (!fs.existsSync(BUILDER)) abort(`missing Blender builder: ${BUILDER}`);
  if (!fs.existsSync(HELPER)) abort(`missing first-party pipeline helper: ${HELPER}`);

  const selected =
    args.only === null ? designs : designs.filter((design) => args.only.includes(design.slug));
  if (args.only !== null) {
    const unknown = args.only.filter((slug) => !designs.some((design) => design.slug === slug));
    if (unknown.length) fail(`unknown design(s): ${unknown.join(", ")}`);
    if (selected.length === 0) fail("--only selected no designs");
  }

  const outDir = path.resolve(args.out);
  let blenderInfo = "dry-run (not probed)";
  if (!args.dryRun) {
    const detected = probeBlender(args.blender);
    if (!detected) abort(`Blender not available at "${args.blender}". Install Blender 5.2 or pass --blender <exe>.`);
    blenderInfo = detected;
    console.log(`[slime-assets] Blender: ${detected}`);
    console.log(`[slime-assets] output: ${outDir}`);
  }

  const reports = [];
  for (const design of selected) {
    const slugDir = path.join(outDir, design.slug);
    const run = buildOne(args, design, outDir);
    if (run.status === "planned") {
      reports.push({
        slug: design.slug,
        name: design.spec.name,
        referenceFile: design.spec.referenceFile,
        status: "planned",
        tris: null,
        bones: null,
        bounds: null,
        clips: null,
        files: {},
      });
      continue;
    }
    if (run.status === "failed") {
      reports.push({
        slug: design.slug,
        name: design.spec.name,
        referenceFile: design.spec.referenceFile,
        status: "failed",
        error: run.error,
        tris: null,
        bones: null,
        bounds: null,
        clips: null,
        files: {},
      });
      continue;
    }
    const validation = validateDesign(design.slug, design.spec, slugDir, args.skipRender);
    const status = validation.errors.length ? "failed" : "ok";
    const report = {
      slug: design.slug,
      name: design.spec.name,
      referenceFile: design.spec.referenceFile,
      status,
      ...(validation.errors.length ? { error: validation.errors.join("; ") } : {}),
      ...(validation.metrics ?? {}),
      ...(validation.clipNames?.length ? { exportedClips: validation.clipNames } : {}),
      files: {
        glb: fs.existsSync(validation.files.glb) ? path.relative(process.cwd(), validation.files.glb).replaceAll("\\", "/") : null,
        blend: fs.existsSync(validation.files.blend) ? path.relative(process.cwd(), validation.files.blend).replaceAll("\\", "/") : null,
        color: fs.existsSync(validation.files.color) ? path.relative(process.cwd(), validation.files.color).replaceAll("\\", "/") : null,
        roughness: fs.existsSync(validation.files.roughness) ? path.relative(process.cwd(), validation.files.roughness).replaceAll("\\", "/") : null,
        preview: fs.existsSync(validation.files.preview) ? path.relative(process.cwd(), validation.files.preview).replaceAll("\\", "/") : null,
        silhouette: fs.existsSync(validation.files.silhouette) ? path.relative(process.cwd(), validation.files.silhouette).replaceAll("\\", "/") : null,
        stats: fs.existsSync(validation.files.stats) ? path.relative(process.cwd(), validation.files.stats).replaceAll("\\", "/") : null,
      },
      ...(fs.existsSync(validation.files.glb) ? { sha256: blobSha256(validation.files.glb) } : {}),
    };
    if (status === "ok") {
      console.log(
        `[slime-assets] OK ${design.slug} tris=${report.tris} bones=${report.bones} clips=${validation.clipNames.join("/")} loopError=${report.loopError.toExponential(2)}`,
      );
    } else {
      console.error(`[slime-assets] FAIL ${design.slug}: ${report.error}`);
    }
    reports.push(report);
  }

  if (args.dryRun) {
    console.log(`[slime-assets] dry-run: ${reports.length} design(s) planned, nothing written.`);
    return;
  }

  writeReports(outDir, reports, blenderInfo, args);
  const failures = reports.filter((report) => report.status !== "ok");
  console.log(`[slime-assets] ${reports.length - failures.length}/${reports.length} designs verified. Handoff: ${path.join(outDir, "ASSETS_HANDOFF.md")}`);
  if (failures.length) {
    console.error(`[slime-assets] failed designs: ${failures.map((report) => report.slug).join(", ")}`);
    process.exitCode = 1;
  }
}

main();
