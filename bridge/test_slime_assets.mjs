// @ts-check
/**
 * test_slime_assets.mjs — behaviour and artifact contract for the S13 slime asset pack.
 *
 * Two layers:
 *  1. Always-on CLI/spec contracts (no Blender, no generated files).
 *  2. Opt-in artifact proof when SLIME_ASSET_DIR points at a generated pack.
 *     The artifact layer parses the real GLB binary/JSON chunk, the real PNG
 *     headers and the real stats files; it never greps the generator source.
 *
 * Run: node --test test_slime_assets.mjs
 * Artifact proof: SLIME_ASSET_DIR=<abs exports/slime-v1> node --test test_slime_assets.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..");
const RUNNER = path.join(REPO, "agent", "generators", "run_slime_assets.mjs");
const SPEC_DIR = path.join(REPO, "agent", "generators", "blender", "slime_specs");
const VFX_MODULE = path.join(REPO, "project_template", "src", "shared", "SlimeAssetVFX.luau");

const SUPPORTED_EFFECTS = new Set(["MeleeSlash", "HeavyImpact", "MagicExplosion", "DashBurst"]);
const CLIP_NAMES = ["Idle", "Extract", "Release"];

/** @param {string[]} args */
function runCli(args, opts = {}) {
  const cwd = opts.cwd ?? fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-cli-"));
  const res = spawnSync(process.execPath, [RUNNER, ...args], {
    cwd,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  });
  return { status: res.status, stdout: String(res.stdout ?? ""), stderr: String(res.stderr ?? ""), cwd };
}

/** @returns {{slug: string, spec: any}[]} */
function loadSpecs() {
  const manifestPath = path.join(SPEC_DIR, "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  return manifest.designs.map((slug) => ({
    slug,
    spec: JSON.parse(fs.readFileSync(path.join(SPEC_DIR, `${slug}.json`), "utf8")),
  }));
}

/** Read the JSON chunk of a binary glTF container. */
function readGlbJson(file) {
  const buf = fs.readFileSync(file);
  assert.equal(buf.readUInt32LE(0), 0x46546c67, `${file}: not a GLB container`);
  assert.equal(buf.readUInt32LE(4), 2, `${file}: unexpected GLB version`);
  assert.equal(buf.readUInt32LE(8), buf.length, `${file}: declared length mismatch`);
  const jsonLength = buf.readUInt32LE(12);
  assert.equal(buf.readUInt32LE(16), 0x4e4f534a, `${file}: first chunk is not JSON`);
  return JSON.parse(buf.subarray(20, 20 + jsonLength).toString("utf8"));
}

/** Read width/height from a PNG IHDR without decoding the pixel data. */
function pngSize(file) {
  const buf = fs.readFileSync(file);
  assert.equal(buf.readUInt32BE(0), 0x89504e47, `${file}: not a PNG`);
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

/** Read both chunks of a binary glTF container. */
function readGlb(file) {
  const buf = fs.readFileSync(file);
  const jsonLength = buf.readUInt32LE(12);
  const jsonEnd = 20 + jsonLength;
  const doc = JSON.parse(buf.subarray(20, jsonEnd).toString("utf8"));
  let bin = null;
  if (jsonEnd + 8 <= buf.length) {
    const binLength = buf.readUInt32LE(jsonEnd);
    if (buf.readUInt32LE(jsonEnd + 4) === 0x004e4942) bin = buf.subarray(jsonEnd + 8, jsonEnd + 8 + binLength);
  }
  return { doc, bin };
}

/** Decode a FLOAT accessor into a flat array. */
function accessorFloats(doc, bin, index) {
  const accessor = doc.accessors[index];
  assert.equal(accessor.componentType, 5126, `accessor ${index}: expected FLOAT`);
  assert.ok(bin, "GLB has no BIN chunk");
  const view = doc.bufferViews[accessor.bufferView];
  const components = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[accessor.type];
  assert.ok(components, `accessor ${index}: unsupported type ${accessor.type}`);
  const base = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0);
  const stride = view.byteStride ?? components * 4;
  const out = new Float32Array(accessor.count * components);
  for (let item = 0; item < accessor.count; item += 1) {
    for (let channel = 0; channel < components; channel += 1) {
      out[item * components + channel] = bin.readFloatLE(base + item * stride + channel * 4);
    }
  }
  return out;
}

function isFiniteNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

// ---------------------------------------------------------------------------
// Always-on: CLI behaviour
// ---------------------------------------------------------------------------

test("--list reports the 13 designs without writing anything", () => {
  const result = runCli(["--list"]);
  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trim().split(/\r?\n/);
  assert.equal(lines[0], "SLIME_ASSET_PACK v1");
  assert.equal(lines[1], "designs=13");
  const rows = lines.slice(2, lines.length - 1).map((line) => line.split("\t"));
  assert.equal(rows.length, 13, `expected 13 design rows, got ${rows.length}`);
  for (const row of rows) {
    assert.match(row[0], /^[a-z][a-z0-9_]*$/);
    assert.ok(row[1] && row[1].length > 2, `missing display name for ${row[0]}`);
    assert.match(row[2], /^height=\d+\.\d$/);
    assert.match(row[3], /^ref=Gemini_Generated_Image_[a-z0-9]+\.jfif$/);
  }
  assert.equal(new Set(rows.map((row) => row[0])).size, 13);
  assert.equal(new Set(rows.map((row) => row[3])).size, 13, "reference files must be unique");
  assert.equal(lines[lines.length - 1], "clips=Idle,Extract,Release");
  assert.deepEqual(fs.readdirSync(result.cwd), [], "--list must not touch the working directory");
});

test("unknown flags are rejected with exit 2 and no writes", () => {
  const result = runCli(["--nope"]);
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--nope/);
  assert.match(result.stderr, /usage/i);
  assert.deepEqual(fs.readdirSync(result.cwd), []);
});

test("--all without --out is rejected before any output is created", () => {
  const cwd = fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-cli-"));
  const result = runCli(["--all"], { cwd });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--out/);
  assert.deepEqual(fs.readdirSync(cwd), []);
});

test("--out without a design selection is rejected", () => {
  const cwd = fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-cli-"));
  const result = runCli(["--out", path.join(cwd, "pack")], { cwd });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--all|--only|selection/i);
  assert.equal(fs.existsSync(path.join(cwd, "pack")), false);
});

test("--only with an unknown slug is rejected before creating the output directory", () => {
  const cwd = fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-cli-"));
  const out = path.join(cwd, "pack");
  const result = runCli(["--only", "not_a_slime", "--out", out], { cwd });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /not_a_slime/);
  assert.equal(fs.existsSync(out), false);
});

test("--dry-run --all plans 13 Blender builds and writes no artifacts", () => {
  const cwd = fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-cli-"));
  const out = path.join(cwd, "pack");
  const result = runCli(["--dry-run", "--all", "--out", out], { cwd });
  assert.equal(result.status, 0, result.stderr);
  const plans = result.stdout.split(/\r?\n/).filter((line) => line.includes("blender.exe") || line.includes("--python"));
  assert.ok(plans.length >= 13, `expected 13 planned builds, got ${plans.length}`);
  for (const slug of loadSpecs().map((entry) => entry.slug)) {
    assert.ok(result.stdout.includes(slug), `dry-run plan missing ${slug}`);
  }
  assert.equal(fs.existsSync(out), false, "dry-run must not create the output directory");
});

// ---------------------------------------------------------------------------
// Opt-in: real Blender CLI regression (SLIME_BLENDER_BIN)
// ---------------------------------------------------------------------------

const BLENDER_BIN = process.env.SLIME_BLENDER_BIN || null;

test("--skip-render builds a valid model and omits both renders", { skip: !BLENDER_BIN && "set SLIME_BLENDER_BIN to run Blender" }, () => {
  const out = fs.mkdtempSync(path.join(process.env.TEMP || os.tmpdir(), "slime-skip-"));
  const result = runCli(["--only", "classic_blue", "--out", out, "--skip-render", "--blender", BLENDER_BIN], { cwd: out });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /1\/1 designs verified/);
  const modelDir = path.join(out, "classic_blue");
  assert.ok(fs.existsSync(path.join(modelDir, "classic_blue.glb")), "missing GLB");
  assert.ok(fs.existsSync(path.join(modelDir, "classic_blue_stats.json")), "missing stats");
  assert.equal(fs.existsSync(path.join(modelDir, "classic_blue_preview.png")), false, "preview must be skipped");
  assert.equal(fs.existsSync(path.join(modelDir, "classic_blue_silhouette.png")), false, "silhouette must be skipped");
});

// ---------------------------------------------------------------------------
// Always-on: spec and module contracts
// ---------------------------------------------------------------------------

test("every spec declares the pack contract and a distinct silhouette", () => {
  const entries = loadSpecs();
  assert.equal(entries.length, 13);
  assert.equal(new Set(entries.map((entry) => entry.spec.builder)).size, 13, "builders must be distinct");
  assert.equal(new Set(entries.map((entry) => entry.spec.referenceFile)).size, 13);
  assert.equal(
    new Set(entries.map((entry) => entry.spec.silhouette)).size,
    13,
    "each design needs its own silhouette note"
  );

  for (const { slug, spec } of entries) {
    assert.equal(spec.schema, "robloxia.slime-asset/v1", slug);
    assert.equal(spec.slug, slug, `${slug}: slug must match its file name`);
    assert.equal(spec.builder, slug, `${slug}: builder must match its slug`);
    assert.match(spec.referenceFile, /^Gemini_Generated_Image_[a-z0-9]+\.jfif$/, slug);
    assert.ok(spec.heightStuds >= 3 && spec.heightStuds <= 9, `${slug}: height out of pet/hero range`);
    assert.ok([512, 1024].includes(spec.textureSize), `${slug}: texture size must be 512 or 1024`);

    for (const role of ["bottom", "top", "spot", "belly", "accent", "accentDeep", "eye", "glint", "cheek", "core"]) {
      assert.match(spec.palette[role], /^#[0-9A-F]{6}$/, `${slug}: palette.${role}`);
    }
    assert.notEqual(spec.palette.bottom, spec.palette.top, `${slug}: needs a real gradient`);

    assert.deepEqual(Object.keys(spec.clips).sort(), ["extract", "idle", "release"], slug);
    for (const frames of Object.values(spec.clips)) {
      assert.ok(Number.isInteger(frames) && frames >= 24 && frames <= 72, `${slug}: clip frames out of range`);
    }

    const vfx = spec.vfx;
    for (const key of ["ambient", "extract", "release"]) {
      assert.ok(SUPPORTED_EFFECTS.has(vfx[key]), `${slug}: unsupported effect ${vfx[key]}`);
    }
    for (const key of ["primary", "secondary"]) {
      assert.equal(vfx[key].length, 3, `${slug}: vfx.${key}`);
      assert.ok(vfx[key].every((channel) => Number.isInteger(channel) && channel >= 0 && channel <= 255), slug);
    }
    assert.ok(isFiniteNumber(vfx.scale) && vfx.scale >= 0.5 && vfx.scale <= 2, `${slug}: vfx.scale`);
    assert.ok(isFiniteNumber(vfx.trauma) && vfx.trauma > 0 && vfx.trauma <= 1, `${slug}: vfx.trauma`);
  }

  const palettes = entries.map((entry) => entry.spec.palette.bottom + entry.spec.palette.top);
  assert.equal(new Set(palettes).size, 13, "no design may be a recolour of another");
});

test("SlimeAssetVFX covers every design with engine-supported effect types", () => {
  const source = fs.readFileSync(VFX_MODULE, "utf8");
  assert.match(source, /^--!strict/m, "module must stay strictly typed");
  for (const { slug } of loadSpecs()) {
    assert.ok(source.includes(`"${slug}"`), `SlimeAssetVFX is missing profile ${slug}`);
  }
  const used = [...source.matchAll(/"?(MeleeSlash|HeavyImpact|MagicExplosion|DashBurst)"?/g)].map((match) => match[1]);
  assert.ok(used.length >= 13, "profiles must reference real effect types");
  for (const effect of new Set(used)) assert.ok(SUPPORTED_EFFECTS.has(effect), `unsupported effect ${effect}`);
  assert.doesNotMatch(source, /\brbxassetid:\/\//, "never fabricate uploaded asset ids");
  assert.doesNotMatch(source, /SoundId\s*=\s*"rbxassetid/, "never fabricate sound ids");
});

// ---------------------------------------------------------------------------
// Opt-in: generated artifact proof
// ---------------------------------------------------------------------------

const ASSET_DIR = process.env.SLIME_ASSET_DIR ? path.resolve(process.env.SLIME_ASSET_DIR) : null;

test("generated pack manifest lists all 13 designs", { skip: !ASSET_DIR && "set SLIME_ASSET_DIR to verify artifacts" }, () => {
  const manifestPath = path.join(ASSET_DIR, "manifest.json");
  assert.ok(fs.existsSync(manifestPath), `missing ${manifestPath}`);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  assert.equal(manifest.schema, "robloxia.slime-asset-pack-run/v1");
  assert.equal(manifest.designs.length, 13);
  assert.deepEqual(new Set(manifest.designs.map((entry) => entry.slug)), new Set(loadSpecs().map((entry) => entry.slug)));
  for (const entry of manifest.designs) {
    assert.equal(entry.status, "ok", `${entry.slug}: ${entry.error ?? "not ok"}`);
    assert.ok(entry.tris > 0 && entry.tris < 20000, `${entry.slug}: tris ${entry.tris}`);
    assert.ok(entry.files.glb && entry.files.blend && entry.files.color && entry.files.roughness && entry.files.preview);
  }
});

test("each GLB embeds mesh, skin, three clips and two textures", { skip: !ASSET_DIR && "set SLIME_ASSET_DIR to verify artifacts" }, () => {
  for (const { slug } of loadSpecs()) {
    const glbPath = path.join(ASSET_DIR, slug, `${slug}.glb`);
    assert.ok(fs.existsSync(glbPath), `${slug}: missing ${glbPath}`);
    const doc = readGlbJson(glbPath);

    assert.ok(Array.isArray(doc.meshes) && doc.meshes.length === 1, `${slug}: expected one merged mesh`);
    for (const mesh of doc.meshes) {
      assert.ok(mesh.primitives.length >= 1);
      for (const primitive of mesh.primitives) {
        for (const attribute of ["POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"]) {
          assert.ok(attribute in primitive.attributes, `${slug}: primitive missing ${attribute}`);
        }
      }
    }

    assert.ok(Array.isArray(doc.skins) && doc.skins.length === 1, `${slug}: expected one skin`);
    assert.ok(doc.skins[0].joints.length >= 3, `${slug}: skin needs real joints`);

    assert.ok(Array.isArray(doc.animations), `${slug}: no animations`);
    const names = doc.animations.map((animation) => animation.name).sort();
    assert.deepEqual(names, [...CLIP_NAMES].sort(), `${slug}: clip names`);
    for (const animation of doc.animations) {
      assert.ok(animation.channels.length > 0, `${slug}/${animation.name}: empty channel list`);
      assert.ok(animation.samplers.length > 0, `${slug}/${animation.name}: empty sampler list`);
      for (const channel of animation.channels) {
        assert.ok(Number.isInteger(channel.target.node), `${slug}/${animation.name}: channel without node`);
      }
    }

    assert.ok(Array.isArray(doc.images) && doc.images.length >= 2, `${slug}: expected colour and roughness images`);
    for (const image of doc.images) {
      assert.ok(Number.isInteger(image.bufferView), `${slug}: texture must be embedded in the GLB`);
    }
    assert.ok(doc.materials.length >= 1, `${slug}: no material`);
    const pbr = doc.materials[0].pbrMetallicRoughness ?? {};
    assert.ok(pbr.baseColorTexture, `${slug}: material has no base colour texture`);
    assert.ok(pbr.metallicRoughnessTexture, `${slug}: material has no roughness texture`);

    const positions = doc.meshes
      .flatMap((mesh) => mesh.primitives)
      .map((primitive) => doc.accessors[primitive.attributes.POSITION]);
    for (const accessor of positions) {
      assert.equal(accessor.min.length, 3);
      assert.equal(accessor.max.length, 3);
      for (const value of [...accessor.min, ...accessor.max]) {
        assert.ok(isFiniteNumber(value), `${slug}: non-finite position bound`);
      }
    }
  }
});

test("stats prove budgets, origin, weights and loop identity", { skip: !ASSET_DIR && "set SLIME_ASSET_DIR to verify artifacts" }, () => {
  for (const { slug, spec } of loadSpecs()) {
    const statsPath = path.join(ASSET_DIR, slug, `${slug}_stats.json`);
    assert.ok(fs.existsSync(statsPath), `${slug}: missing stats`);
    const stats = JSON.parse(fs.readFileSync(statsPath, "utf8"));

    assert.equal(stats.schema, "robloxia.slime-asset-stats/v1");
    assert.equal(stats.slug, slug);
    assert.ok(stats.tris > 0 && stats.tris < 20000, `${slug}: tris ${stats.tris}`);
    assert.ok(stats.vertices > 0);
    assert.equal(stats.nonFinite, 0, `${slug}: non-finite geometry`);
    assert.ok(stats.uv.minU >= -1e-4 && stats.uv.maxU <= 1 + 1e-4, `${slug}: UV outside 0-1`);
    assert.ok(stats.uv.minV >= -1e-4 && stats.uv.maxV <= 1 + 1e-4, `${slug}: UV outside 0-1`);
    assert.equal(stats.rig.maxInfluences <= 4, true, `${slug}: more than 4 influences`);
    assert.ok(stats.rig.maxWeightError < 1e-4, `${slug}: unnormalised weights`);
    assert.ok(stats.rig.deformBones >= 2, `${slug}: rig too small`);
    assert.ok(stats.rig.bones.includes("Root"), `${slug}: rig needs a Root bone`);

    assert.deepEqual(stats.clips.map((clip) => clip.name), CLIP_NAMES, `${slug}: clip order`);
    for (const clip of stats.clips) {
      assert.ok(clip.frames >= 24, `${slug}/${clip.name}: too short`);
      assert.ok(clip.channels > 0, `${slug}/${clip.name}: no animated channels`);
      assert.ok(clip.durationSeconds > 0.5, `${slug}/${clip.name}: duration`);
    }
    assert.ok(stats.loopError < 1e-4, `${slug}: Idle does not loop (${stats.loopError})`);

    assert.ok(Math.abs(stats.origin.bottomZ) <= 1e-3, `${slug}: origin is not at the bottom`);
    assert.ok(Math.abs(stats.origin.xyCenter[0]) <= spec.heightStuds * 0.06, `${slug}: X not centred`);
    assert.ok(Math.abs(stats.origin.xyCenter[1]) <= spec.heightStuds * 0.06, `${slug}: Y not centred`);

    const size = stats.bounds.size;
    assert.ok(Math.abs(size[2] - spec.heightStuds) <= spec.heightStuds * 0.18, `${slug}: height ${size[2]} vs ${spec.heightStuds}`);
    assert.ok(size[2] > size[1] * 0.6, `${slug}: implausibly flat body`);

    for (const key of ["triangleBudget", "normalizedWeights", "uvInRange", "bottomOrigin", "clipCount", "loopIdentity", "texturesEmbedded", "blendTexturesPacked", "quaternionContinuity"]) {
      assert.equal(stats.checks[key], true, `${slug}: check ${key} failed`);
    }
    const color = pngSize(path.join(ASSET_DIR, slug, `${slug}_color.png`));
    assert.equal(color.width, spec.textureSize);
    assert.equal(color.height, spec.textureSize);
    const rough = pngSize(path.join(ASSET_DIR, slug, `${slug}_roughness.png`));
    assert.equal(rough.width, spec.textureSize);
  }
});

test("previews and editable Blender scenes exist for all 13 designs", { skip: !ASSET_DIR && "set SLIME_ASSET_DIR to verify artifacts" }, () => {
  for (const { slug } of loadSpecs()) {
    const preview = path.join(ASSET_DIR, slug, `${slug}_preview.png`);
    const blend = path.join(ASSET_DIR, slug, `${slug}.blend`);
    assert.ok(fs.existsSync(preview), `${slug}: missing preview`);
    assert.ok(fs.statSync(preview).size > 10_000, `${slug}: preview looks empty`);
    const size = pngSize(preview);
    assert.ok(size.width >= 512 && size.height >= 512, `${slug}: preview too small`);
    assert.ok(fs.existsSync(blend), `${slug}: missing editable .blend`);
    assert.ok(fs.statSync(blend).size > 50_000, `${slug}: .blend looks empty`);
  }
});

test("exported clips keep quaternion continuity and a closed Idle loop", { skip: !ASSET_DIR && "set SLIME_ASSET_DIR to verify artifacts" }, () => {
  for (const { slug } of loadSpecs()) {
    const { doc, bin } = readGlb(path.join(ASSET_DIR, slug, `${slug}.glb`));
    for (const animation of doc.animations) {
      for (const channel of animation.channels) {
        const sampler = animation.samplers[channel.sampler];
        const values = accessorFloats(doc, bin, sampler.output);
        const property = channel.target.path;
        const components = property === "rotation" ? 4 : 3;
        const count = values.length / components;
        assert.ok(count >= 2, `${slug}/${animation.name}: ${property} has ${count} keys`);
        for (const value of values) assert.ok(isFiniteNumber(value), `${slug}/${animation.name}: non-finite ${property}`);
        for (let index = 1; index < count; index += 1) {
          if (property === "rotation") {
            let dot = 0;
            for (let axis = 0; axis < 4; axis += 1) {
              dot += values[(index - 1) * 4 + axis] * values[index * 4 + axis];
            }
            assert.ok(dot > -0.01, `${slug}/${animation.name}: quaternion flip at key ${index} (dot ${dot})`);
          } else {
            let delta = 0;
            for (let axis = 0; axis < components; axis += 1) {
              delta = Math.max(delta, Math.abs(values[(index - 1) * components + axis] - values[index * components + axis]));
            }
            assert.ok(delta < 5, `${slug}/${animation.name}: ${property} jump at key ${index} (${delta})`);
          }
        }
        if (animation.name === "Idle") {
          for (let axis = 0; axis < components; axis += 1) {
            const first = values[axis];
            const last = values[(count - 1) * components + axis];
            assert.ok(Math.abs(first - last) < 2e-3, `${slug}: Idle ${property} is not closed (${first} vs ${last})`);
          }
        }
      }
    }
  }
});

test(".blend files keep both textures packed", { skip: !(ASSET_DIR && BLENDER_BIN) && "set SLIME_ASSET_DIR and SLIME_BLENDER_BIN" }, () => {
  const script = [
    "import bpy, glob, json, os",
    `root = r"${ASSET_DIR}"`,
    "out = {}",
    "for path in sorted(glob.glob(os.path.join(root, '*', '*.blend'))):",
    "    bpy.ops.wm.open_mainfile(filepath=path)",
    "    name = os.path.basename(path)[:-6]",
    "    out[name] = [(image.name, image.packed_file is not None, image.size[0]) for image in bpy.data.images"
      + " if image.name not in ('Render Result', 'Viewer Node') and image.size[0] > 0]",
    "print('BLENDPACK_JSON ' + json.dumps(out))",
  ].join("\n");
  const run = spawnSync(BLENDER_BIN, ["-b", "--factory-startup", "--python-expr", script], {
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(run.status, 0, String(run.stderr));
  const line = String(run.stdout).split(/\r?\n/).find((entry) => entry.includes("BLENDPACK_JSON"));
  assert.ok(line, "missing .blend readback output");
  const report = JSON.parse(line.slice(line.indexOf("BLENDPACK_JSON ") + "BLENDPACK_JSON ".length));
  for (const { slug } of loadSpecs()) {
    const images = report[slug];
    assert.ok(Array.isArray(images) && images.length >= 2, `${slug}: expected two embedded images`);
    for (const [name, packed, size] of images) {
      assert.equal(packed, true, `${slug}/${name}: texture is not packed`);
      assert.equal(size, 1024, `${slug}/${name}: unexpected texture size ${size}`);
    }
  }
});
