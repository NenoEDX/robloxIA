// @ts-check
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  MUTATION_SURFACE_STACKS,
  VFX_STORYBOARDS,
  auditGameAssets,
  composeOriginalVfx,
  generateFrameworkBlueprint,
  getNextNanoBananaRequest,
  listVfxRecipes,
  loadEcosystemRegistry,
  loadLihFolkCatalogs,
  registerEcosystemAsset,
  searchAllAssets,
  validateMapBlueprint,
} from "./asset_ecosystem.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, "..");

test("S1: connects to 1.2 GB LihFolk Vault V2 / LihFolk-Assets when present AND works in standalone mode on fresh GitHub clones", () => {
  // 1. Standalone mode (simulating a fresh GitHub clone without the 1.2 GB pack)
  const standalone = loadLihFolkCatalogs("__FORCE_STANDALONE__");
  assert.equal(standalone.connected, false);
  assert.deepEqual(standalone.models, []);

  const standaloneAudit = auditGameAssets({
    requiredAssets: [{ assetId: "classic_blue", name: "Slime Azul" }],
    packRoot: "__FORCE_STANDALONE__",
  });
  assert.equal(standaloneAudit.ok, true);
  assert.equal(standaloneAudit.resolved[0].source, "ecosystem_registry");

  // 2. Connected mode (when the 1.2 GB LihFolk pack is available locally)
  const catalogs = loadLihFolkCatalogs();
  if (catalogs.connected) {
    assert.equal(catalogs.models.length, 815, "Must load all 815 A1-A18 pass models");
    assert.equal(catalogs.materials.length, 204, "Must load all 204 pass materials");
    assert.equal(catalogs.skies.length, 48, "Must load all 48 skies");
    assert.ok(catalogs.animations.length >= 9, "Must load shippable animations");
  }
});

test("S2: 1-by-1 Nano Banana queue returns one asset at a time for complex models and batch of up to 10 for accessories/mutations", () => {
  const next = getNextNanoBananaRequest();
  assert.equal(next.hasPending, true);
  assert.equal(next.batchMode, "single_1x1");
  assert.equal(next.currentPosition, 1);
  assert.ok(next.queueLength >= 3);
  assert.ok(next.request);
  assert.equal(next.request.assetId, "verja_abismal_3d");
  assert.match(next.request.nanoBananaPrompt, /3\/4 front orthographic turnaround view/);
  assert.match(next.request.nanoBananaPrompt, /ZERO harsh cast shadows/);
  assert.ok(next.request.routes.routeA_potentAiSameChat);
  assert.ok(next.request.routes.routeB_studioMcpNative);
  assert.ok(next.request.routes.routeC_externalAppPlusCleanup);

  const batch10 = getNextNanoBananaRequest(undefined, { mode: "batch10" });
  assert.equal(batch10.hasPending, true);
  assert.equal(batch10.batchMode, "sheet_10x");
  assert.ok(batch10.request.batchCount >= 3 && batch10.request.batchCount <= 10);
  assert.match(batch10.request.nanoBananaPrompt, /2 rows x 5 columns/);
  assert.ok(batch10.request.items.some((i) => i.assetId === "mutacion_cuernos_cristal"));

  const fw = generateFrameworkBlueprint("RelicForge");
  assert.equal(fw.systemName, "RelicForge");
  assert.equal(fw.modules.length, 5);
});

test("S1 & S4: auditGameAssets resolves ready 3D models, flags missing ones, and forbids mindless primitive blocks", () => {
  const audit = auditGameAssets({
    requiredAssets: [
      { assetId: "classic_blue", name: "Slime Azul" },
      { assetId: "Badge_01", name: "Emblem Badge 01" },
      { assetId: "maquina_extractora_3d", name: "Máquina Extractora 3D" },
      {
        assetId: "bloque_basura",
        name: "Decoración sin criterio",
        sourceType: "primitive_blocks",
      },
    ],
  });

  assert.equal(audit.ok, false);
  assert.equal(audit.resolved.length, 2);
  assert.equal(audit.resolved[0].source, "ecosystem_registry");
  assert.equal(audit.resolved[1].source, "lihfolk_asset_pack");
  assert.equal(audit.missing.length, 1);
  assert.equal(audit.missing[0].assetId, "maquina_extractora_3d");
  assert.equal(audit.violations.length, 1);
  assert.equal(audit.violations[0].code, "MINDLESS_DECORATION_FORBIDDEN");
});

test("S5: registerEcosystemAsset adds reusable 3D asset in isolated temp registry and advances the 1-by-1 queue", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ecosystem-reg-"));
  try {
    const tmpRegistryPath = path.join(tmpDir, "ecosystem_registry.json");
    fs.copyFileSync(
      path.join(REPO_ROOT, "assets", "ecosystem_registry.json"),
      tmpRegistryPath,
    );

    const before = getNextNanoBananaRequest(tmpRegistryPath);
    assert.equal(before.request?.assetId, "verja_abismal_3d");

    const record = registerEcosystemAsset(tmpRegistryPath, {
      assetId: "verja_abismal_3d",
      name: "Verja Modular Abismal 3D",
      category: "module",
      glbPath: "exports/ecosystem/verja_abismal_3d/verja_abismal_3d.glb",
      tris: 1640,
      heightStuds: 5.5,
      tags: ["fence", "verja", "abyssal", "modular"],
    });

    assert.equal(record.status, "ready_3d");
    assert.equal(record.reusableInFutureGames, true);

    const after = getNextNanoBananaRequest(tmpRegistryPath);
    assert.equal(after.request?.assetId, "maquina_extractora_3d");

    const search = searchAllAssets("verja", { registryPath: tmpRegistryPath });
    assert.equal(search.customMatches.length, 1);
    assert.equal(search.customMatches[0].assetId, "verja_abismal_3d");
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("S4: validateMapBlueprint enforces Stage 1 (Top-Down Plan), Stage 2 (Per-Zone References), and 3D Props", () => {
  const missingStage1 = validateMapBlueprint({
    topDownPlan: { approved: false, sourceImageOrGrid: "" },
    zones: [],
  });
  assert.equal(missingStage1.valid, false);
  assert.equal(missingStage1.stage, "awaiting_stage_1_top_down_plan");

  const missingStage2 = validateMapBlueprint({
    topDownPlan: {
      approved: true,
      sourceImageOrGrid: "plans/slime_pit_top_down_v1.png",
      mainPathWidthStuds: 24,
    },
    zones: [
      {
        zoneId: "santuario_central",
        zoneReferences: [],
        decorationMode: "curated_3d_models",
        props3d: [
          { assetId: "classic_blue", placementRule: "placeOnGround" },
        ],
      },
    ],
  });
  assert.equal(missingStage2.valid, false);
  assert.equal(missingStage2.stage, "awaiting_stage_2_zone_references");

  const mindlessRejected = validateMapBlueprint({
    topDownPlan: {
      approved: true,
      sourceImageOrGrid: "plans/slime_pit_top_down_v1.png",
      mainPathWidthStuds: 24,
    },
    zones: [
      {
        zoneId: "santuario_central",
        zoneReferences: ["refs/santuario_ref_01.png"],
        decorationMode: "primitive_blocks",
        props3d: [
          { assetId: "classic_blue", placementRule: "placeOnGround" },
        ],
      },
    ],
  });
  assert.equal(mindlessRejected.valid, false);
  assert.ok(mindlessRejected.errors.some((e) => e.code === "MINDLESS_DECORATION_FORBIDDEN"));

  const validBlueprint = validateMapBlueprint({
    topDownPlan: {
      approved: true,
      sourceImageOrGrid: "plans/slime_pit_top_down_v1.png",
      mainPathWidthStuds: 24,
    },
    zones: [
      {
        zoneId: "santuario_central",
        zoneReferences: ["refs/santuario_ref_01.png"],
        decorationMode: "curated_3d_models",
        props3d: [
          { assetId: "classic_blue", placementRule: "placeOnGround" },
          { assetId: "Badge_01", placementRule: "modularSnap" },
        ],
      },
    ],
  });
  assert.equal(validBlueprint.valid, true);
  assert.equal(validBlueprint.stage, "ready_for_mcp_build");
});

test("S3: VFX recipes & Luau modules exist and enforce 3-value rule + two-stage map builder", () => {
  const slashRecipes = listVfxRecipes("espada");
  assert.ok(slashRecipes.length >= 1);
  assert.equal(slashRecipes[0].preset, "SlashSweep");

  const beamRecipes = listVfxRecipes("kamehameha");
  assert.equal(beamRecipes.length, 1);
  assert.equal(beamRecipes[0].preset, "BeamLaser");

  assert.equal(VFX_STORYBOARDS.length, 2);
  assert.equal(VFX_STORYBOARDS[0].storyboardId, "event_meteor_mutation_shower");
  assert.equal(VFX_STORYBOARDS[0].phases.length, 5);
  assert.ok(MUTATION_SURFACE_STACKS.length >= 2);

  const customMeteor = composeOriginalVfx({
    prompt: "Lluvia de meteoritos de cristal sobre una planta",
    element: "ice",
  });
  assert.equal(customMeteor.resolvedKind, "world_mutation_event");
  assert.equal(customMeteor.tickRateHz, 60);
  assert.equal(customMeteor.fluidAnimationTimeline.length, 6);
  assert.ok(customMeteor.required3DMeshesForBatch10.length >= 3);
  assert.ok(
    customMeteor.required3DMeshesForBatch10.every((m) => m.detailTier === "low_batch_10"),
  );

  const vfxLuau = fs.readFileSync(
    path.join(REPO_ROOT, "project_template", "src", "shared", "VFXRecipeCatalog.luau"),
    "utf8",
  );
  assert.match(vfxLuau, /--!strict/);
  assert.match(vfxLuau, /hotCore/);
  assert.match(vfxLuau, /elementBody/);
  assert.match(vfxLuau, /darkInkRim/);

  const mapLuau = fs.readFileSync(
    path.join(REPO_ROOT, "project_template", "src", "shared", "MapZoneBuilder.luau"),
    "utf8",
  );
  assert.match(mapLuau, /--!strict/);
  assert.match(mapLuau, /MINDLESS_DECORATION_FORBIDDEN/);
  assert.match(mapLuau, /MISSING_TOP_DOWN_PLAN/);
  assert.match(mapLuau, /MISSING_ZONE_REFERENCE/);

  const normPy = fs.readFileSync(
    path.join(REPO_ROOT, "agent", "generators", "blender", "normalize_external_3d.py"),
    "utf8",
  );
  assert.match(normPy, /RobloxBudgetDecimate/);
  assert.match(normPy, /underRoblox20k/);
});

test("S2 Route C: normalize_external_3d.py runs in Blender 5.2 and normalizes an external GLB to Roblox budget and bottom origin", (t) => {
  const blenderBin =
    process.env.BLENDER_BIN || "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe";
  if (!fs.existsSync(blenderBin)) {
    t.skip("Blender 5.2 binary not installed at default path");
    return;
  }

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "route-c-blender-"));
  try {
    const rawGlb = path.join(tmpDir, "raw_input.glb");
    const outGlb = path.join(tmpDir, "clean_output.glb");
    const outStats = path.join(tmpDir, "clean_output_stats.json");

    // Generate a dense, off-center, unscaled test GLB in Blender first
    const makeRawPy = [
      "import bpy",
      "bpy.ops.wm.read_factory_settings(use_empty=True)",
      "bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=12.0, location=(15.0, -9.0, 22.0))",
      `bpy.ops.export_scene.gltf(filepath=${JSON.stringify(rawGlb)}, export_format='GLB')`,
    ].join("; ");

    const rawRun = spawnSync(blenderBin, ["-b", "--factory-startup", "--python-expr", makeRawPy], {
      encoding: "utf8",
    });
    assert.equal(rawRun.status, 0, `Raw GLB creation failed: ${rawRun.stderr}`);
    assert.ok(fs.existsSync(rawGlb), "Raw GLB must exist");

    const scriptPath = path.join(
      REPO_ROOT,
      "agent",
      "generators",
      "blender",
      "normalize_external_3d.py",
    );
    const normRun = spawnSync(
      blenderBin,
      [
        "-b",
        "--factory-startup",
        "--python-exit-code",
        "1",
        "--python",
        scriptPath,
        "--",
        "--input",
        rawGlb,
        "--out",
        outGlb,
        "--target-tris",
        "1800",
        "--height-studs",
        "5.5",
      ],
      { encoding: "utf8" },
    );
    assert.equal(normRun.status, 0, `normalize_external_3d.py failed: ${normRun.stderr}`);
    assert.ok(fs.existsSync(outGlb), "Normalized GLB must exist");
    assert.ok(fs.existsSync(outStats), "Stats JSON must exist");

    const stats = JSON.parse(fs.readFileSync(outStats, "utf8"));
    assert.ok(stats.trisBefore > 1800, "Input should have been high-poly (>1800 tris)");
    assert.ok(stats.trisAfter <= 2070, `Decimated tris (${stats.trisAfter}) must respect target budget`);
    assert.equal(stats.checks.underRoblox20k, true);
    assert.equal(stats.checks.bottomOrigin, true);
    assert.equal(stats.checks.singleMaterial, true);
    assert.ok(Math.abs(stats.heightStuds - 5.5) < 0.05, `Height (${stats.heightStuds}) must match 5.5 studs`);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

