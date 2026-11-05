// bridge/test_open_cloud.mjs
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  MAX_OPEN_CLOUD_TRIANGLES,
  resolveOpenCloudMimeType,
  validateOpenCloudAssetCandidate,
  uploadAssetOpenCloud,
  updateAssetManifestWithCloudId,
} from "./open_cloud.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, "..");

test("resolveOpenCloudMimeType supports .glb and .fbx for Model and rejects external .rbxm/.rbxmx", () => {
  assert.equal(resolveOpenCloudMimeType("prop.glb", "Model"), "model/gltf-binary");
  assert.equal(resolveOpenCloudMimeType("character_rig.FBX", "Model"), "model/fbx");
  assert.equal(resolveOpenCloudMimeType("sfx_hit.mp3", "Audio"), "audio/mpeg");
  assert.equal(resolveOpenCloudMimeType("sfx_hit.ogg", "Audio"), "audio/ogg");
  assert.equal(resolveOpenCloudMimeType("palette_256.png", "Decal"), "image/png");

  assert.throws(
    () => resolveOpenCloudMimeType("synthesized_outside_studio.rbxm", "Model"),
    /rechaza modelos \.rbxm\/\.rbxmx sintetizados fuera de Studio/
  );
});

test("validateOpenCloudAssetCandidate enforces < 20,000 triangles and <= 20 MB limits", () => {
  const fakeFs = {
    existsSync: () => true,
    statSync: () => ({ size: 1024 * 512 }),
  };

  const ok = validateOpenCloudAssetCandidate({
    filePath: "mesh_chest_iron.glb",
    assetType: "Model",
    triangleCount: 4200,
    fsImpl: fakeFs,
  });
  assert.equal(ok.mimeType, "model/gltf-binary");
  assert.equal(ok.triangleCount, 4200);

  assert.throws(
    () =>
      validateOpenCloudAssetCandidate({
        filePath: "mesh_overbudget.glb",
        assetType: "Model",
        triangleCount: MAX_OPEN_CLOUD_TRIANGLES + 1,
        fsImpl: fakeFs,
      }),
    /excede el límite de 20000 triángulos/
  );

  const hugeFs = {
    existsSync: () => true,
    statSync: () => ({ size: 21 * 1024 * 1024 }),
  };
  assert.throws(
    () =>
      validateOpenCloudAssetCandidate({
        filePath: "huge_model.fbx",
        assetType: "Model",
        fsImpl: hugeFs,
      }),
    /excede el límite de 20 MB/
  );
});

test("uploadAssetOpenCloud uploads .fbx with model/fbx and polls async operation until done", async () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "raase-opencloud-"));
  const fbxPath = path.join(tmpDir, "mesh_boss_rig.fbx");
  fs.writeFileSync(fbxPath, Buffer.from("KAYDARA_FBX_BINARY_DUMMY"));

  const calls = [];
  const fakeFetch = async (url, init) => {
    calls.push({ url, init });
    if (String(url).endsWith("/assets/v1/assets")) {
      const bodyStr = init.body.toString("utf8");
      assert.ok(bodyStr.includes("Content-Type: model/fbx"));
      assert.ok(bodyStr.includes('"groupId":"999888"'));
      return {
        ok: true,
        status: 200,
        json: async () => ({ path: "operations/op-fbx-123" }),
      };
    }
    return {
      ok: true,
      status: 200,
      json: async () => ({
        done: true,
        response: { assetId: "7788990011" },
      }),
    };
  };

  try {
    const res = await uploadAssetOpenCloud({
      filePath: fbxPath,
      assetType: "Model",
      displayName: "mesh_boss_rig",
      triangleCount: 8500,
      apiKey: "test-open-cloud-key",
      groupId: "999888",
      fetchImpl: fakeFetch,
      pollIntervalMs: 5,
    });

    assert.equal(res.assetId, "7788990011");
    assert.equal(res.rbxassetid, "rbxassetid://7788990011");
    assert.equal(res.mimeType, "model/fbx");
    assert.equal(calls.length, 2);

    const manifestPath = path.join(tmpDir, "asset_manifest.json");
    const updated = updateAssetManifestWithCloudId(manifestPath, {
      assetName: "mesh_boss_rig",
      assetId: res.assetId,
      format: "FBX",
      tris: 8500,
    });
    assert.equal(updated.rbxassetid, "rbxassetid://7788990011");
    assert.equal(updated.tris, 8500);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("blender_export_example.py includes both Vertex Color baking, Palette Atlas UV collapsing, and <20k tris guard", () => {
  const scriptPath = path.join(
    REPO_ROOT,
    "skills-roblox",
    "roblox-36-asset-pipeline",
    "scripts",
    "blender_export_example.py"
  );
  const content = fs.readFileSync(scriptPath, "utf8");
  assert.ok(content.includes("def bake_materials_to_vertex_colors("));
  assert.ok(content.includes("def map_uv_to_palette_atlas("));
  assert.ok(content.includes("def validate_mesh_budget("));
  assert.ok(content.includes("def apply_deterministic_transforms("));
  assert.ok(content.includes("MAX_ROBLOX_TRIANGLES = 20000"));
  assert.ok(content.includes("export_colors=True"));
  assert.ok(content.includes("colors_type='SRGB'"));
});
