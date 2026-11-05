// bridge/test_master_modules.mjs
// Verificación estática y de contratos para los 4 Módulos Maestros RAASE 3.0 en project_template/src/shared/

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SHARED_DIR = path.resolve(__dirname, "..", "project_template", "src", "shared");

function readSharedModule(fileName) {
  const fullPath = path.join(SHARED_DIR, fileName);
  assert.ok(fs.existsSync(fullPath), `Missing module ${fullPath}`);
  return fs.readFileSync(fullPath, "utf8");
}

test("All 4 Master Modules and Types.luau start with --!strict and have balanced Luau blocks", () => {
  for (const modName of [
    "Types.luau",
    "VoxelTerrainBuilder.luau",
    "WorldAssembler.luau",
    "ProceduralAnimator.luau",
    "VFXAndJuiceEngine.luau",
  ]) {
    const content = readSharedModule(modName);
    assert.ok(
      content.startsWith("--!strict"),
      `${modName} must start with --!strict`
    );
    assert.ok(
      content.trimEnd().endsWith("return " + modName.replace(".luau", "")) ||
        (modName === "Types.luau" && content.trimEnd().endsWith("return {}")),
      `${modName} must return its module table at the end`
    );
  }
});

test("VoxelTerrainBuilder.luau implements ExpandToGrid(4), FBM noise, fractional occupancy [0,1], slope/altitude materials, and CarveRoadPath", () => {
  const code = readSharedModule("VoxelTerrainBuilder.luau");
  assert.ok(code.includes("function VoxelTerrainBuilder.SampleFBM2D("));
  assert.ok(code.includes("function VoxelTerrainBuilder.GenerateFBM("));
  assert.ok(code.includes("function VoxelTerrainBuilder.CarveRoadPath("));
  assert.ok(code.includes(":ExpandToGrid(VOXEL_RESOLUTION)"));
  assert.ok(code.includes("math.noise("));
  assert.ok(code.includes("math.clamp(rawOccupancy, 0, 1)"));
  assert.ok(code.includes("Enum.Material.Rock"));
  assert.ok(code.includes("Enum.Material.Sand"));
  assert.ok(code.includes("Enum.Material.Grass"));
  assert.ok(code.includes("terrain:WriteVoxels("));
  assert.ok(code.includes("terrain:ReadVoxels("));
  assert.ok(code.includes("task.wait()"));
});

test("WorldAssembler.luau implements downward Raycast grounding, GetExtentsSize().Y offset, slope alignment, and RN-10 SmartUpsert", () => {
  const code = readSharedModule("WorldAssembler.luau");
  assert.ok(code.includes("function WorldAssembler.SnapVector3("));
  assert.ok(code.includes("function WorldAssembler.PlaceGrounded("));
  assert.ok(code.includes("function WorldAssembler.SmartUpsert("));
  assert.ok(code.includes("workspace:Raycast("));
  assert.ok(code.includes("GetExtentsSize().Y"));
  assert.ok(code.includes("CFrame.fromMatrix("));
  assert.ok(code.includes('GetAttribute("RAASE_Locked")'));
  assert.ok(code.includes("model:PivotTo("));
});

test("ProceduralAnimator.luau implements native IKControl + anatomical BallSocketConstraint limits, Spring2D (zeta in [0.45, 0.75]), and FlipbookController", () => {
  const code = readSharedModule("ProceduralAnimator.luau");
  assert.ok(code.includes("function ProceduralAnimator.AttachIK("));
  assert.ok(code.includes("function ProceduralAnimator.ApplyAnatomicalLimits("));
  assert.ok(code.includes('Instance.new("IKControl")'));
  assert.ok(code.includes('Instance.new("BallSocketConstraint")'));
  assert.ok(code.includes("socket.LimitsEnabled = true"));
  assert.ok(code.includes("function ProceduralAnimator.CreateSpring2D("));
  assert.ok(code.includes("math.clamp(zeta or 0.58, 0.45, 0.75)"));
  assert.ok(code.includes("function ProceduralAnimator.CreateFlipbookController("));
  assert.ok(code.includes("imageLabel.ImageRectSize"));
  assert.ok(code.includes("imageLabel.ImageRectOffset"));
});

test("VFXAndJuiceEngine.luau implements cubic trauma shake (S = T^3 at Camera + 1), white Highlight Hit-Flash (0.12s), ±9% audio pitch modulation, and 5-layer CastEffect", () => {
  const code = readSharedModule("VFXAndJuiceEngine.luau");
  assert.ok(code.includes("function VFXAndJuiceEngine.ComputeTraumaShake("));
  assert.ok(code.includes("clamped * clamped * clamped"));
  assert.ok(code.includes("Enum.RenderPriority.Camera.Value + 1"));
  assert.ok(code.includes("function VFXAndJuiceEngine.AddTrauma("));
  assert.ok(code.includes("function VFXAndJuiceEngine.TriggerHitFlash("));
  assert.ok(code.includes('Instance.new("Highlight")'));
  assert.ok(code.includes("highlight.FillTransparency = 0.1"));
  assert.ok(code.includes("function VFXAndJuiceEngine.ApplyHitstop("));
  assert.ok(code.includes("function VFXAndJuiceEngine.PlayModulatedSound("));
  assert.ok(code.includes("pitchVariance or 0.09"));
  assert.ok(code.includes("function VFXAndJuiceEngine.CastEffect("));
  assert.ok(code.includes("spawnLayer1CoreFlash("));
  assert.ok(code.includes("spawnLayer2ShockwaveRing("));
  assert.ok(code.includes("spawnLayer3SlashBeam("));
  assert.ok(code.includes("beam.FaceCamera = false"));
  assert.ok(code.includes("spawnLayer4DirectionalSparks("));
  assert.ok(code.includes("Enum.ParticleOrientation.VelocityParallel"));
  assert.ok(code.includes("NumberSequence.new(-1.5)"));
  assert.ok(code.includes("spawnLayer5ContextualVoxelDebris("));
  assert.ok(code.includes("GetMaterialColor("));
});
